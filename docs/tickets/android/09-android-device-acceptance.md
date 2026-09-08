# 09: Android device acceptance and desktop regression

**What to build:** Validate the Android release candidate on real hardware and prove that adding Android support has not regressed the existing desktop products.

**Blocked by:** 08: Android CI and APK/AAB packaging.

**Status:** ready-for-agent

- [ ] Test on at least one arm64-v8a Android phone and one emulator configuration.
- [ ] Verify URL sharing, foreground download, background/locked-screen behaviour, notification actions, export, open, and share.
- [ ] Verify network interruption, low storage, revoked export access, cancellation, retry, and process recreation.
- [ ] Run the complete desktop build and test matrix, including CTest 6/6 and existing package checks.
- [ ] Record known device/OS limitations and decide whether the Android build is ready for wider testing.
