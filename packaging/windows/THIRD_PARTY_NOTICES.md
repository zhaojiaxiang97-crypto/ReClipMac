# Third-party notices

## Qt 6

This application is dynamically deployed with Qt 6.8.3 components. Review the applicable Qt license terms and ship the corresponding LGPL/GPL texts with every release:

- <https://www.qt.io/licensing/open-source-lgpl-obligations>
- <https://www.qt.io/licensing>

The package must preserve the ability to replace the dynamically linked Qt libraries as required by the selected Qt license.

## FFmpeg

The process package includes the exact FFmpeg executable build selected by
`RECLIP_TOOL_BIN`. When the SDK option is enabled, the package also includes
the matching shared FFmpeg SDK DLLs selected by `RECLIP_FFMPEG_ROOT`; those DLLs
are used for in-process probe, remux, merge, and audio conversion. The command-
line binaries remain in `bin/` for formats that the first SDK backend does not
yet handle. The packaging script copies the matching `LICENSE.txt` and, when
available, `build-info.txt` into `licenses/`.

The experimental `-EnableYtDlpSdk` package instead omits the command-line
tools and only advertises the embedded resolver/native single-format download
and SDK post-processing MVP. Unsupported
formats do not silently fall back to an executable in that package.

This project currently uses an LGPL shared build; verify the exact configure
flags, source revision, and license before publishing.

- <https://ffmpeg.org/legal.html>
- <https://ffmpeg.org/donations.html>

## yt-dlp

The portable package includes `yt-dlp.exe` from the runtime-tool directory selected at packaging time. `yt-dlp` is distributed under the project license and notices available from its upstream repository; record the exact version and license text for the binary used in each release.

With `-EnableYtDlpSdk`, the pinned yt-dlp wheel is used instead of the executable.
The wheel's license files and distribution metadata are retained under
`runtime/python/Lib/site-packages/`; exact artifacts and hashes are recorded in
`licenses/Python-dependencies.json`.

- <https://github.com/yt-dlp/yt-dlp>
- <https://github.com/yt-dlp/yt-dlp/blob/master/LICENSE>

## Embedded CPython and certificate bundle (optional)

The experimental embedded package includes CPython 3.13.15 from the Python
Software Foundation's NuGet distribution, plus the pinned certifi wheel.
CPython's `LICENSE.txt` is preserved in `runtime/python/`, including the notices
for its bundled standard-library/native components. Certifi's distribution
license files are retained in its `.dist-info` directory. Review these actual
files and `runtime/python/dependencies.json` when updating or distributing the
package. This variant does not include EJS, QuickJS or curl-cffi.

## KDE Kirigami and Extra CMake Modules

When the optional Kirigami shell is enabled, the portable package includes
Kirigami 6.8.0 and Extra CMake Modules 6.8.0. Kirigami is licensed under
LGPL-2.0-or-later and ECM is licensed under BSD-3-Clause; preserve the exact
source notices and the applicable license texts in release artifacts:

- <https://github.com/KDE/kirigami>
- <https://github.com/KDE/extra-cmake-modules>

## QuickMaterial

The settings controls embed a source subset of QuickMaterial for its Material
3 shape, spacing and interaction-state tokens. QuickMaterial is licensed
under MIT; preserve its license text with release artifacts:

- <https://github.com/Neftedollar/quickmaterial>

## Ant Design Icons

The shared QML icon renderer uses path data adapted from the Ant Design Icons
project maintained by the Ant Group / Alibaba design ecosystem. The icon set
is distributed under the MIT License; preserve the upstream notice with
release artifacts:

- <https://github.com/ant-design/ant-design-icons>
- <https://github.com/ant-design/ant-design-icons/blob/master/LICENSE>

## ReClip

The application source remains licensed under the repository `LICENSE` and `NOTICE` files, which are copied into the package `licenses` directory.
