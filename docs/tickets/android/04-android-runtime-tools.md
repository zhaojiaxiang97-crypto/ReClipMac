# 04: Android yt-dlp and FFmpeg runtime

**What to build:** Prove and implement a supported Android arm64 runtime strategy for media inspection and conversion, with deterministic tool discovery and clear failure reporting.

**Blocked by:** 01: Android build baseline.

**Status:** in-progress

- [x] Choose and document a prototype strategy for Android `yt-dlp`: an embedded Python engine instead of the desktop-only standalone executable path.
- [x] Choose and document an arm64-v8a FFmpeg proof-of-concept build and its licence/distribution obligations.
- [x] Make runtime discovery independent of the device `PATH` and desktop-only configuration paths.
- [x] Verify tool versions when a candidate is found and expose missing/incompatible runtime errors to the UI.
- [x] Run a real smoke test that parses a public test URL and completes one MP4 download.

## Implementation notes

- Android now checks the app-private runtime directory first:
  `/data/user/0/com.reclip.videodownloader/files/bin` (resolved through
  `PlatformPaths::runtimeDirectory()`). Desktop packaged locations and PATH
  lookup remain unchanged.
- `MainActivity` can copy optional `android/assets/bin/*` files into that
  directory on first launch and applies an executable permission. The repository
  intentionally does not bundle yt-dlp or FFmpeg binaries yet.
- The Settings page now explains the Android runtime path instead of telling
  Android users to modify a desktop PATH.

## Open decision

Before adding binaries, choose a reproducible arm64-v8a distribution strategy
and record its source, version, checksum, update process, and licence notices:

1. A supported standalone yt-dlp executable plus an Android-compatible FFmpeg
   build packaged as ABI-specific assets.
2. An embedded Python/runtime approach for yt-dlp plus a separately packaged
   FFmpeg library or executable. **Selected for the prototype; the Android
   engine bridge and end-to-end media test remain open.**
3. A different download engine that avoids shipping a Python runtime.

Until this decision is made, the Android UI can validate tool discovery and
failure reporting, but a real media download cannot be accepted as complete.

## GitHub research snapshot (2026-09-05)

### yt-dlp findings

- The official [`yt-dlp/yt-dlp`](https://github.com/yt-dlp/yt-dlp) project does
  publish `yt-dlp_linux_aarch64`, but its own release table describes it as a
  Linux **glibc 2.17+** standalone binary. The corresponding musl build is also
  labelled for Linux, not Android/Bionic. It must not be copied into
  `android/assets/bin` and treated as an Android runtime without a real-device
  test and a supported libc strategy.
- The official Android installation guidance points users to Termux. Termux is
  useful as a reference for building against Android/Bionic, but its package
  root and dynamic-library layout are tied to the Termux app namespace; it is
  not a drop-in runtime for this APK.
- [`ffmpegkit-maintained/yt-dlp-android`](https://github.com/ffmpegkit-maintained/yt-dlp-android)
  v2.0.2 is the closest permissive-license Android wrapper found: it embeds
  CPython 3.13 through Chaquopy in an AAR and exposes a Java API. It supports
  `arm64-v8a` and `x86_64`, but the AAR is approximately 60--80 MB, yt-dlp is
  fixed at library-build time, and the repository has a small maintenance
  footprint. It is an Android engine candidate, not a standalone executable
  for the current `QProcess` path.
- [`yausername/youtubedl-android`](https://github.com/yausername/youtubedl-android)
  is a more established Android wrapper and bundles yt-dlp, Python and an
  FFmpeg module, but the repository is GPL-3.0. Adding it directly to this
  MIT project requires an explicit licensing decision and corresponding
  notices; it is not the default choice.

### FFmpeg findings

- [`arthenica/ffmpeg-kit-next`](https://github.com/arthenica/ffmpeg-kit-next)
  is the official continuation of FFmpegKit. It supports Android and
  `arm64-v8a`, but publishes source/build scripts rather than ready-made
  binaries. Its Android build produces an AAR and Kotlin/Java API, so using it
  requires an Android backend bridge instead of the current `QProcess` call.
- [`hzw1199/Android-FFmpeg-Prebuilt`](https://github.com/hzw1199/Android-FFmpeg-Prebuilt)
  contains direct `ffmpeg` and `ffprobe` executables for Android
  `arm64-v8a`, minimum API 28, and 16 KB page-size alignment. The repository
  claims a `--disable-gpl --disable-nonfree` LGPL-2.1 build and includes
  FFmpeg 9.0, 8.1.1 and 8.0.1. It is a useful **proof-of-concept candidate**
  for the current `QProcess` design, but it has no GitHub releases and a very
  small commit history; production use requires source/configuration review,
  checksum pinning and a reproducible rebuild.
- The original [`arthenica/ffmpeg-kit`](https://github.com/arthenica/ffmpeg-kit)
  repository is archived and should not be selected for a new Android runtime.

### First FFmpeg proof of concept

- Pinned source: `hzw1199/Android-FFmpeg-Prebuilt`, commit
  `90231cc0105aef4f76926b911535f5eb73511b86`, FFmpeg `9.0`.
- Artifact: `ffmpeg-9.0/bin/ffmpeg`, SHA-256
  `9085507B0DC32643B4D6D084A7E7D3469EF17907A7BA15C22D3997ED09C932AA`.
- The artifact was pushed to the connected Xiaomi Android 14 / API 34 /
  arm64-v8a device and passed `ffmpeg -version`, synthetic one-second MP4
  generation, and a second read/decode pass. It was tested only under
  `/data/local/tmp`; it has not been bundled into the APK.
- Re-fetching the pinned artifact is now scripted by
  `scripts/android/Fetch-AndroidFfmpeg.ps1`. Generated binaries remain under
  the ignored `.artifacts/` directory until the licensing and release decision
  is complete.

### Android yt-dlp AAR initialization proof of concept

- Pinned Maven Central artifact: `dev.ffmpegkit-maintained:yt-dlp-android:2.0.2`.
- SHA-256: `D2E71858F4C144F021534E658B94D0C3616818B662C848903F1F2FE9DEC4A7D0`.
- The AAR is fetched by `scripts/android/Fetch-AndroidYtDlp.ps1` into the
  ignored `.artifacts/android-runtime/` directory; it is not committed to Git.
- `scripts/android/Build-Android.ps1 -WithYtDlpAndroid` stages the verified AAR
  into the generated `.build/.../android-package/libs` directory. A normal build
  remains dependency-free and keeps the base Android shell buildable.
- The AAR-enabled arm64-v8a Debug APK built successfully and was installed on
  the connected Xiaomi 24094RAD4C (Android 14 / API 34 / arm64-v8a) device.
- The device log reported `yt-dlp Android runtime initialized`, confirming that
  the AAR, Chaquopy CPython runtime and native arm64 libraries were merged and
  initialized in the Qt APK.
- This is an initialization proof only. The current Qt backend still expects a
  desktop `QProcess` executable for desktop builds, while Android now has an
  optional Java/C++ engine bridge for metadata inspection and a foreground
  download request.

### Android engine bridge proof of concept (2026-09-06)

- Added `src/AndroidDownloadEngine.{h,cpp}`. It keeps the desktop
  `QProcess` backend intact and routes Android callbacks through registered JNI
  methods and request ids.
- Added the optional
  `android/optional-src/com/reclip/videodownloader/AndroidYtDlpBridge.java`.
  It calls the embedded Python `yt_dlp` module for structured metadata and the
  AAR Java API for download progress, completion and cancellation.
- `MediaInspector` now uses the Android bridge when the AAR is present and
  falls back to the existing executable path otherwise. `DownloadManager` has
  the corresponding single-download/progress/cancel path. `DownloadQueue` now
  has the corresponding Android single-task bridge path; background execution
  and formal runtime distribution review remain open.
- The connected Xiaomi device accepted an external `VIEW` Intent for
  `https://example.com`. yt-dlp returned the expected unsupported-URL result,
  which reached the QML error state without a crash. This validates the
  Android-to-C++ callback path, but it is not the authorised-media success
  test required for completion.
- After the bridge was added, the Windows Release build and all six CTest
  targets were run again successfully. This confirms the Android-only JNI
  implementation remains isolated from the desktop backend.

### Public MP4 success smoke test (2026-09-06)

- Test URL: `https://assets.testfiles.dev/video/sample-3s.mp4`, a small public
  test fixture suitable for media-pipeline verification.
- On the connected Xiaomi Android 14 / API 34 device, an external `VIEW`
  intent reached the QML page and produced the parsed title `sample-3s`.
- Tapping `下载 MP4` completed the Android bridge request and produced
  `files/downloads/VideoDownloader-sample-3s.mp4` in the app-private storage.
  The device reported 122,786 bytes and the application process remained
  alive.
- This confirms the successful parse and direct MP4 download path. It does
  not yet prove FFmpeg-backed MP3 extraction, cancellation, retry, queue
  persistence or background execution.

The same public fixture was also added to the mobile queue and started with
`全部开始`. The task reached `下载完成` and `已保存` on the device, including
the existing-output fallback used when yt-dlp reports an idempotent download
without a new destination line.

### FFmpegKit audio and MP3 extraction slice (2026-09-06)

- Added an optional Android FFmpegKit audio AAR: `dev.ffmpegkit-maintained:ffmpeg-kit-audio:8.1.7`.
- Pinned and verified its runtime dependencies `smart-exception-common:0.2.1` and
  `smart-exception-java:0.2.1`; the build script stages all three artefacts only
  into the generated Android build directory.
- `AndroidYtDlpBridge` now downloads the selected audio stream and invokes
  FFmpegKit through its Java callback API with `libmp3lame`, while retaining a
  clear error callback when the optional runtime is not present.
- A deterministic local fixture containing three seconds of MPEG-4 video and
  AAC audio was served through `adb reverse` to the connected Xiaomi device.
  The source output was 45,814 bytes and the generated
  `VideoDownloader-android-audio-test.mp3` was 15,489 bytes. FFmpegKit logs
  confirmed `aac (native) -> mp3 (libmp3lame)` and `success=true`.
- A public fixture with video but no audio was also exercised; the conversion
  failed with the expected “output file does not contain any stream” diagnostic,
  proving that a missing audio stream is reported rather than silently producing
  an invalid MP3.

The Android FFmpeg/MP3 slice is now complete for the controlled test fixture.
Cancellation and retry are now also accepted on the connected device using a
slow local MP4 stream: the UI reached `已取消`, the bridge removed the generated
`.part/.ytdl` files, and a subsequent retry reached `下载完成` with a complete
4,956,176-byte MP4. Background execution and formal licence/distribution review
remain open.

### Decision direction

1. Do not bundle the official Linux `yt-dlp_linux_aarch64` binary.
2. For the first Android end-to-end proof, test the direct Android FFmpeg
   executable from `hzw1199/Android-FFmpeg-Prebuilt` only after recording an
   exact commit and SHA-256, and keep it outside the default release until
   its provenance is reviewed.
3. For yt-dlp, prefer an Android embedded-Python engine and introduce an
   `AndroidDownloadEngine` bridge. Keep desktop `QProcess` as a separate
   backend. The MIT `yt-dlp-android` wrapper can be evaluated for a prototype,
   while the GPL `youtubedl-android` package remains a reference implementation
   unless the project licence is deliberately changed.
4. If a long-term binary-only design is required, build both Android tools
   ourselves from pinned source/configuration in CI. The binary-only option is
   not considered complete until the real device passes `--version`, URL
   inspection, MP4 muxing, MP3 extraction, cancellation and retry tests.
