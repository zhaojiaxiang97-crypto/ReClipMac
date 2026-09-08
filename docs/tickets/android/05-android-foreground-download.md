# 05: Android foreground download flow

**What to build:** Deliver the first complete Android download experience: a user can paste or share an authorised public URL, inspect it, choose MP4 or MP3, download it in the foreground, and receive a usable output file.

**Blocked by:** 02: Android app shell and URL intake; 03: Android storage and export directory; 04: Android yt-dlp and FFmpeg runtime.

**Status:** in-progress

- [x] Connect URL intake to media inspection and format selection on Android.
- [x] Show preparing, downloading, completed and failed states with progress information for the Android bridge prototype.
- [x] Write the result to the selected export location and make it available through Android sharing/open actions.
- [x] Support cancellation and retry without leaving an orphaned process or partial result.
- [x] Verify the basic flow with a public non-DRM test fixture on an arm64-v8a device.

### Implementation slice (2026-09-06)

- `DownloadManager` now runs a foreground Android bridge request for a direct
  MP4 download, with progress, completion, cancellation and error callbacks.
- `DownloadQueue` now uses the same bridge on Android instead of requiring
  desktop executable paths. The mobile queue page exposes `全部开始`, runs
  tasks sequentially and shows the completed/available output state.
- The Xiaomi Android 14 / API 34 device verified URL intake, metadata parsing,
  direct MP4 download, queue start and queue completion. The output remains in
  app-private storage when no export directory is selected.
- The optional FFmpegKit audio AAR is now wired into the same bridge. A local
  three-second AAC + MPEG-4 fixture produced a 15,489-byte MP3 on the device,
  and the FFmpeg log confirmed `libmp3lame` completed successfully.
- A slow local MP4 fixture was used to verify cancellation at 1.3%: the UI
  entered `已取消`, `.part/.ytdl` files were removed, and the retry action
  generated a complete 4,956,176-byte MP4. The Android progress panel was also
  adjusted so long speed/ETA text cannot compress the cancel button to zero
  width on a narrow screen.
- SAF export now uses the corrected five-string JNI signature. The same
  4,956,176-byte MP4 was copied into the selected SAF directory, and the
  completed-file share action opened the Android system chooser.
- Long-running background protection now moves into ticket 06: the Android
  bridge starts an in-process `dataSync` foreground service with progress and
  cancellation notification actions. Notification retry and abnormal-network
  recovery remain in ticket 06.
