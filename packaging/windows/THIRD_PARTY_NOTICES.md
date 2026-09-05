# Third-party notices

## Qt 6

This application is dynamically deployed with Qt 6.8.3 components. Review the applicable Qt license terms and ship the corresponding LGPL/GPL texts with every release:

- <https://www.qt.io/licensing/open-source-lgpl-obligations>
- <https://www.qt.io/licensing>

The package must preserve the ability to replace the dynamically linked Qt libraries as required by the selected Qt license.

## FFmpeg

The portable package includes the exact FFmpeg shared build selected by `RECLIP_TOOL_BIN`. The packaging script copies its `LICENSE.txt` into `licenses/FFmpeg-LICENSE.txt` when the source distribution provides it. This project uses an LGPL shared build; verify the exact configure flags and license before publishing.

- <https://ffmpeg.org/legal.html>
- <https://ffmpeg.org/donations.html>

## yt-dlp

The portable package includes `yt-dlp.exe` from the runtime-tool directory selected at packaging time. `yt-dlp` is distributed under the project license and notices available from its upstream repository; record the exact version and license text for the binary used in each release.

- <https://github.com/yt-dlp/yt-dlp>
- <https://github.com/yt-dlp/yt-dlp/blob/master/LICENSE>

## KDE Kirigami and Extra CMake Modules

When the optional Kirigami shell is enabled, the portable package includes
Kirigami 6.8.0 and Extra CMake Modules 6.8.0. Kirigami is licensed under
LGPL-2.0-or-later and ECM is licensed under BSD-3-Clause; preserve the exact
source notices and the applicable license texts in release artifacts:

- <https://github.com/KDE/kirigami>
- <https://github.com/KDE/extra-cmake-modules>

## ReClip

The application source remains licensed under the repository `LICENSE` and `NOTICE` files, which are copied into the package `licenses` directory.
