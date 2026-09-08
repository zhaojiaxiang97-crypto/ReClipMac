# 02: Android app shell and URL intake

**What to build:** Make the Android application feel native for the first interaction: a phone-friendly shell accepts a pasted URL or a URL shared from another application and presents it to the download flow.

**Blocked by:** 01: Android build baseline.

**Status:** ready-for-download-validation

- [x] Provide a phone-first single-column shell with the existing download, queue, and settings destinations.
- [x] Handle the Android back action by returning from queue/settings to the new-download page before allowing the app to close.
- [x] Accept a URL from the clipboard and from Android `ACTION_SEND`/`ACTION_VIEW` intents.
- [x] Preserve the incoming URL across rotation and a short background/foreground transition in the API 35 emulator; the connected device also accepts explicit `ACTION_VIEW`/`ACTION_SEND` delivery and survives background/foreground recovery.
- [x] Keep the desktop navigation and URL entry behaviour unchanged.

## Implementation notes

- `android/AndroidManifest.xml` declares the launcher, text-share, and HTTP(S)
  view entry points.
- `android/src/com/reclip/videodownloader/MainActivity.java` captures the
  initial and subsequent intents and exposes a small native bridge.
- `AppController` registers the JNI callback and exposes the pending URL to
  QML. QML consumes and clears the transient value so sharing the same URL
  twice still triggers a fresh inspection.
- The fallback Qt Quick Controls shell and the optional Kirigami shell both
  consume the initial URL and implement the page-level Android back action.
- On the Xiaomi Android 14 device, the bottom navigation opens the queue page,
  and the system back action returns to the new-download page without closing
  the activity. The close-request path is handled in addition to the Qt key
  event path because some Qt/Android combinations deliver Back that way.
- A physical landscape rotation has now been verified on the connected device;
  the QML shell, bottom navigation, input field, and activity remain alive.
- A real media URL inspection/download remains outside this ticket's completed
  acceptance scope.
