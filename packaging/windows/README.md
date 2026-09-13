# Windows portable package

This directory contains the Windows packaging entry point. It creates a portable folder that includes the Qt runtime, QML imports, platform plugins, `yt-dlp`, FFmpeg, and license notices.

From the repository root:

```powershell
.\packaging\windows\package.ps1 -Configuration Release
```

To package the desktop FFmpeg SDK backend (the SDK DLLs are copied beside the
application and the command-line backend remains available as a compatibility
fallback):

```powershell
$env:RECLIP_FFMPEG_ROOT = "$PWD\.third_party\ffmpeg\windows-x64"
.\packaging\windows\package.ps1 -Configuration Release -EnableFfmpegSdk
```

The default output is `.artifacts/windows/ReClip-Release`. Build files are kept under `.build/package-windows-release`. To use another Qt or runtime-tool installation, set `RECLIP_QT_ROOT` and `RECLIP_TOOL_BIN` before invoking the script.

The SDK option requires a development package with `include`, `lib`, `bin`, and
the matching `build-info.txt` when available. Without the option, the existing
process backend is built.

When `-EnableFfmpegSdk` is used, `FfprobeService` supplies the ffprobe-equivalent
media inspection through `libavformat`, `libavcodec`, and `libavutil`; the package
does not copy `ffprobe.exe`. Command-line `ffprobe` is included only in the
fully compatible process package.

The script intentionally refuses to overwrite an existing output directory. Remove an old package explicitly or pass a new `-OutputDirectory`.

For the experimental in-process yt-dlp resolver/native single-format downloader
and FFmpeg SDK package, first run `scripts/Fetch-PythonRuntime.ps1`, then use
`package.ps1 -Configuration Release -EnableYtDlpSdk`. This variant also enables
the FFmpeg and FFprobe SDK paths and omits `yt-dlp.exe`, `python.exe`, `ffmpeg.exe`,
and `ffprobe.exe`.
Its default output is `.artifacts/windows/ReClip-Release-ytdlp-sdk`. It is not a
full replacement for all CLI-supported sites/protocols; see the
[embedded runtime guide](../../docs/yt-dlp-embedded.md) for capabilities,
tests, dependencies and the process-observation limitation.

The packaged application searches `<package>\bin` before the system `PATH`, so a clean Windows machine does not need Qt, CMake, Visual Studio, or globally installed download tools. A real network download should be tested with a user-authorized, non-DRM URL before publishing a release.
