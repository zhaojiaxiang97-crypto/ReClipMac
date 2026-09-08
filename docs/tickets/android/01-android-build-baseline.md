# 01: Android build baseline

**What to build:** Establish the Android build path for Video Downloader and produce an arm64-v8a Debug APK that can be installed and launched on a supported emulator and a real device.

**Blocked by:** None (can start immediately).

**Status:** ready-for-runtime-validation

- [x] Record the Qt Android Kit, Android SDK, NDK, JDK, and Gradle versions used by the project.
- [x] Generate an arm64-v8a Debug APK without changing the existing desktop build flow.
- [x] Install and launch the latest x86_64 APK on an API 35 Android emulator.
- [x] Install and launch the arm64-v8a APK on at least one physical Android device.
- [x] Confirm that the QML shell starts, rotates, and survives a basic background/foreground cycle on the emulator.
- [x] Confirm a physical portrait/landscape rotation on the connected Android device.
- [x] Document toolchain prerequisites and the known Android limitations.

## Implementation notes

- Qt 6.8.3 host Kit: `C:\Qt\6.8.3\msvc2022_64`.
- Qt Android target Kits: `C:\Qt\6.8.3\android_arm64_v8a` and `C:\Qt\6.8.3\android_x86_64`.
- Android SDK: `C:\Android\sdk`; NDK `26.1.10909125`; JDK `17.0.12`; Gradle `8.10`; AGP `8.6.0`.
- Reproducible build command:

  ```powershell
  powershell -ExecutionPolicy Bypass -File scripts/android/Build-Android.ps1 -Abi arm64-v8a -BuildType Debug
  ```

- The arm64-v8a and x86_64 APKs both build successfully. The arm64 APK is
  packaged as `com.reclip.videodownloader`, labelled `Video Downloader`, with
  minimum API 28 and target API 35.
- AEHD 2.2 is now installed and usable. The API 35 x86_64 emulator starts
  successfully with hardware acceleration and the x86_64 APK installs and
  launches.
- A Xiaomi 24094RAD4C running Android 14 / API 34 with `arm64-v8a` is
  connected. The arm64 APK installs and launches, and the app survives
  navigation, system back, background/foreground checks, and a physical
  landscape rotation. The landscape UI hierarchy reports `rotation="1"` and
  the Qt activity remains resumed.
- The arm64 system image remains unsuitable for this x86_64 host, so the
  physical device is the current arm64 validation target.
