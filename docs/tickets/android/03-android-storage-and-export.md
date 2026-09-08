# 03: Android storage and export directory

**What to build:** Let an Android user choose where completed media should be exported while keeping temporary files inside the app sandbox and preserving the choice across launches.

**Blocked by:** 01: Android build baseline.

**Status:** complete

- [x] Define the Android app-private default download location through `PlatformPaths` while preserving desktop defaults.
- [x] Keep the working output inside the app-private directory and represent the user export location as a persisted SAF tree URI instead of a desktop absolute path.
- [x] Let the user select an export directory through the Android file picker.
- [x] Persist and restore the selected location without relying on a desktop absolute path.
- [x] Report invalid, revoked, full, or unavailable locations with an actionable message while keeping the private copy available.
- [x] Open the selected export directory and route completed-file open/share actions through Android system intents.

## Implementation notes

- `PlatformPaths` keeps Android working output under the app-private data directory;
  `QStandardPaths::CacheLocation` remains separate for transient cache data.
- `PlatformStorage` is the QML-facing platform boundary. Desktop builds keep the
  existing filesystem behaviour; Android uses Storage Access Framework (SAF),
  persistable tree permissions, and `FileProvider` for private files.
- `MainActivity` starts the first picker request in the conventional `Download`
  directory because Android 11+ rejects granting a storage root.
- The chosen directory is stored as a `content://` URI plus a display label in
  `QSettings`. Reopening the app restores the label and the persisted permission.
- A completed download is first written to the private working directory. If an
  export is configured, it is copied into the selected SAF directory; a failed
  export leaves the private file usable and reports the reason.

## Device acceptance

- Xiaomi 24094RAD4C, Android 14 / API 34 / `arm64-v8a`: the picker opened in
  landscape, a child folder was selected and confirmed, the selected label was
  shown in Settings, the state survived force-stop/relaunch, and `打开导出目录`
  reopened the selected folder.
- With the ticket 04 Android runtime enabled, an authorised local MP4 was
  downloaded to private storage and copied into the selected SAF directory.
  Both copies were 4,956,176 bytes. The completed-file `分享` action opened the
  Android `MiuiChooserActivity` share panel, and no broad storage permission was
  required.
