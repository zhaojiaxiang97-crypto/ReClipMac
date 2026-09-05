# Third-party notices

## Qt 6

The AppImage contains dynamically deployed Qt 6.8.3 components. Preserve the applicable LGPL/GPL texts and the ability to replace dynamically linked Qt libraries for every release:

- <https://www.qt.io/licensing/open-source-lgpl-obligations>
- <https://www.qt.io/licensing>

## FFmpeg

The AppImage includes the FFmpeg build selected by `RECLIP_TOOL_BIN`. Verify the exact configure flags and ship the matching license text before publishing.

- <https://ffmpeg.org/legal.html>

## yt-dlp

The AppImage includes `yt-dlp` from the runtime-tool directory selected at packaging time. Record the exact binary version and license text for each release.

- <https://github.com/yt-dlp/yt-dlp>
- <https://github.com/yt-dlp/yt-dlp/blob/master/LICENSE>

## KDE Kirigami and Extra CMake Modules

When the optional Kirigami shell is enabled, the AppImage includes Kirigami
6.8.0 and Extra CMake Modules 6.8.0. Kirigami is licensed under
LGPL-2.0-or-later and ECM is licensed under BSD-3-Clause; ship the exact
source notices and applicable license texts with the AppImage:

- <https://github.com/KDE/kirigami>
- <https://github.com/KDE/extra-cmake-modules>

## ReClip

The application source remains licensed under the repository `LICENSE` and `NOTICE` files, copied into the AppImage documentation directory.
