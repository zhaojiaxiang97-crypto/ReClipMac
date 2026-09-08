# 08: Android CI and APK/AAB packaging

**What to build:** Make Android builds repeatable in CI and publish a testable APK artifact with the correct ABI, version metadata, permissions, runtime assets, and licence notices.

**Blocked by:** 06: Android background download and recovery; 07: Android localisation and accessibility.

**Status:** ready-for-agent

- [ ] Add an Android build job that produces an arm64-v8a Debug APK for every relevant change.
- [ ] Verify that runtime tools, QML imports, icons, permissions, and Android metadata are included correctly.
- [ ] Run emulator smoke tests for launch, URL intake, settings, queue state, and a non-network failure path.
- [ ] Document the transition from Debug APK to signed APK/AAB without storing signing credentials in the repository.
- [ ] Preserve the existing Windows, macOS, and Linux CI jobs and their current checks.
