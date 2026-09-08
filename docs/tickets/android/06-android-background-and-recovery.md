# 06: Android background download and recovery

**What to build:** Make a running download behave predictably when the user locks the device, switches applications, or the Android process is interrupted; the queue and its outcome remain understandable.

**Blocked by:** 05: Android foreground download flow.

**Status:** in-progress

- [x] Select and implement the Android execution model for long downloads: an in-process `dataSync` foreground service keeps the Qt process important while the bridge request is active.
- [x] Display notification progress, successful/failed terminal state and a cancellation action.
- [x] Add a notification retry action and verify the complete notification action matrix on the device.
- [x] Persist enough queue state to recover or clearly mark a task after process recreation.
- [x] Handle cancellation and network failure without corrupting the queue; failed
  requests remove their request-scoped temporary files and remain retryable.
- [x] Verify that a revoked Android notification permission does not prevent the
  queue from starting a foreground download service or completing the download.
- [x] Verify that repeated queue-start requests do not create duplicate downloads
  or duplicate output files.
- [x] Verify Wi-Fi loss during an active download produces a retryable failure
  with the normalized network message and no corrupt output.
- [x] Verify the storage preflight rejects an unavailable Android volume before
  starting a service or writing an output file.
- [ ] Test a physically low-free-space volume without corrupting the queue.
- [x] Verify that desktop queue behaviour remains unchanged.

## Implemented slice (2026-09-06)

- `DownloadForegroundService` is declared with `foregroundServiceType="dataSync"`.
- Android 13+ notification permission is requested at application start; the
  `downloads` channel is low-importance and uses a stable foreground ID.
- `AndroidYtDlpBridge` starts the service before submitting the yt-dlp task,
  updates the notification from progress callbacks, and publishes a separate
  terminal notification when the request completes or fails.
- `DownloadQueue` stores a compact JSON representation in `QSettings`. A task
  found in `downloading` or `exporting` state at the next launch becomes
  `interrupted` with an explicit retry action; queue loading never starts a
  network request by itself.
- Failed and cancelled queue tasks carry their persistent task ID into the
  terminal notification. The notification `重试` action opens the app with a
  retry intent; QML consumes it and calls the existing C++ queue retry path.
- Download startup now checks that the target storage volume is ready and has at
  least 16 MiB available. Desktop and Android error mapping turns connection
  refusal, remote disconnects, DNS failures, network-unreachable errors and
  disk-full errors into actionable retry guidance.
- Android yt-dlp failures clean up their request-scoped `.part` and `.ytdl`
  files asynchronously, including failures where yt-dlp did not report a
  final output path back to Qt.
- Notification permission is treated as a user-visible capability rather than a
  download prerequisite: the app still requests it on launch, while the
  foreground service remains usable if Android reports it as denied.
- Windows Debug and Release CTest both pass 6/6 after the persistence change.

## Device acceptance

- Xiaomi 24094RAD4C, Android 14 / API 34 / arm64-v8a: a controlled slow MP4
  download kept `DownloadForegroundService` at `isForeground=true` with
  `foregroundId=4101` after the application was sent to Home. The notification
  exposed progress and `取消`; after completion the service exited and the
  separate `下载完成` notification remained visible. The output file was
  4,956,176 bytes.
- Xiaomi 24094RAD4C, Android 14 / API 34 / arm64-v8a: a refused local HTTP
  connection produced a terminal notification with a `重试` action. Triggering
  the same action intent reloaded the persisted queue task and started a new
  foreground request (`isForeground=true`); the second failure again produced
  a terminal notification with `重试`.
- Xiaomi 24094RAD4C, Android 14 / API 34 / arm64-v8a: after a rebuilt APK
  started a controlled slow download, stopping the local HTTP server produced
  `下载失败` with `网络连接中断，请检查网络后重试`; the retry action remained
  available and no `.part/.ytdl` file remained in the app-private download
  directory.
- Xiaomi 24094RAD4C, Android 14 / API 34 / arm64-v8a: stopping the app process
  at approximately 29.7% progress caused the foreground service to exit; after
  relaunch, the queue showed `应用关闭时中断，可重试` and the persisted task state
  was `interrupted`, with no automatic network restart.
- Xiaomi 24094RAD4C, Android 14 / API 34 / arm64-v8a: while a slow download was
  active, turning the screen off moved the device to `mWakefulness=Dozing` while
  `DownloadForegroundService` remained `isForeground=true`; waking the device
  did not produce an app crash.
- Xiaomi 24094RAD4C, Android 14 / API 34 / arm64-v8a: with
  `POST_NOTIFICATIONS` revoked (`granted=false`, `USER_FIXED`), starting a
  queued controlled slow download from the real QML queue entry point still
  produced `isForeground=true`; the task completed with a 4,956,176-byte MP4,
  the service exited normally, and logcat contained no Java/runtime crash.
  The test restored the permission and removed its temporary output afterward.
- Xiaomi 24094RAD4C, Android 14 / API 34 / arm64-v8a: tapping `全部开始`
  twice in quick succession while a controlled slow task was queued kept one
  active queue task and one foreground service; the task completed with one
  4,956,176-byte output file and no duplicate process or output was left.
- Xiaomi 24094RAD4C, Android 14 / API 34 / arm64-v8a: turning Wi-Fi off during
  a slow download from the development machine caused the foreground task to
  end as retryable `下载失败`, with `网络连接中断，请检查网络后重试`; the
  service exited and no output file was retained. Wi-Fi was restored afterward.
- Xiaomi 24094RAD4C, Android 14 / API 34 / arm64-v8a: pointing the temporary
  download directory at the unavailable `/proc` volume was rejected before
  starting the foreground service, with `存储空间不足或下载位置不可用，请清理空间后重试`;
  no output file was written. This validates the safe preflight path, not a
  physically full device volume.

## Remaining work

- Test a physically low-free-space volume.
  Decide whether interrupted tasks
  should later be resumed automatically or remain user-confirmed retries.
