# ReClipQt

[English](#english) | [简体中文](#简体中文)

## English

ReClipQt is the Qt 6/QML cross-platform migration of the original [ReClipMac](https://github.com/zhaojiaxiang97-crypto/ReClipMac) media downloader. The active implementation uses QML/Qt Quick for the UI, C++/Qt for application logic, and CMake for builds on Windows, macOS, and Linux.

The original SwiftUI macOS implementation has been removed from this working tree. The upstream GitHub repository remains the historical source of that implementation.

### Features

- Parse media URLs with `yt-dlp`.
- Download MP4 video or extract MP3 audio with FFmpeg.
- Select available video quality.
- Show sequential queue progress, speed, and remaining time.
- Cancel, retry, reveal, or remove a download.
- Persist download and tool settings locally.
- Use light/dark QML themes, clipboard paste, and drag-and-drop URLs.

### Requirements

- Qt 6.8 or later with Qt Quick, QML, Quick Controls, and Shader Tools.
- CMake 3.21 or later and a C++17 compiler.
- `yt-dlp`, `ffmpeg`, and `ffprobe`.
- Optional adaptive UI dependency: KDE Kirigami 6.8.0 with Extra CMake Modules 6.8.0.

### Build and test

Windows with Visual Studio:

```powershell
cmake -S . -B .build/windows -G "Visual Studio 17 2022" -A x64 -DBUILD_TESTING=ON
cmake --build .build/windows --config Release
ctest --test-dir .build/windows -C Release --output-on-failure
```

To enable the Kirigami application shell on Windows, install the pinned local
dependency first and then configure the project. The script uses Kirigami
6.8.0, which is compatible with the current Qt 6.8.3 kit:

```powershell
powershell -ExecutionPolicy Bypass -File scripts/Install-Kirigami.ps1
cmake -S . -B .build/windows-kirigami -G "Visual Studio 17 2022" -A x64 -DRECLIP_ENABLE_KIRIGAMI=ON
cmake --build .build/windows-kirigami --config Release
```

If Kirigami is not installed, CMake automatically keeps the Qt Quick Controls
2 responsive shell from `Main.qml`. Set `-DRECLIP_ENABLE_KIRIGAMI=OFF` to make
that fallback explicit.

macOS or Linux:

```bash
qt-cmake -S . -B .build/desktop -DCMAKE_BUILD_TYPE=Release -DBUILD_TESTING=ON
cmake --build .build/desktop --config Release
ctest --test-dir .build/desktop --output-on-failure
```

Generated files are intentionally kept out of the repository root: `.build/`
contains CMake build trees and `.artifacts/` contains packaged applications.
The pre-existing root-level caches were moved to `.build/legacy/` and are kept
there as a recoverable migration archive.

### Packaging

- Windows portable package: `packaging/windows/package.ps1`
- macOS `.app`: `packaging/macos/package.sh`
- Linux AppImage: `packaging/linux/package-appimage.sh`
- Cross-platform CI: `.github/workflows/ci.yml`

### Source layout

```text
CMakeLists.txt
src/                    C++/Qt application logic
qml/                    QML UI, theme, and components
tests/                  Qt Test coverage
packaging/              Platform packaging scripts and notices
scripts/                Dependency bootstrap scripts
.github/workflows/      Cross-platform CI
.build/                 Local CMake build trees (generated, ignored)
.artifacts/             Packaged applications (generated, ignored)
```

Only download media you have permission to save. ReClipQt does not bypass DRM, paywalls, authentication, or platform access restrictions.

### License

MIT. See [LICENSE](LICENSE) and [NOTICE](NOTICE).

## 简体中文

ReClipQt 是原始 [ReClipMac](https://github.com/zhaojiaxiang97-crypto/ReClipMac) 媒体下载器的 Qt 6/QML 跨平台改造版本。当前活跃实现使用 QML/Qt Quick 构建界面，使用 C++/Qt 承担业务逻辑，并使用 CMake 支持 Windows、macOS 和 Linux 桌面端。

原来的 SwiftUI macOS 实现已从当前工作树移除；GitHub 上游仓库仍保留这部分历史代码。

### 功能

- 使用 `yt-dlp` 解析媒体链接。
- 使用 FFmpeg 下载 MP4 或提取 MP3。
- 选择可用的视频清晰度。
- 显示串行下载队列、进度、速度和剩余时间。
- 支持取消、重试、打开位置和删除任务。
- 持久化下载目录和工具配置。
- 支持浅色/深色 QML 主题、剪贴板粘贴和链接拖拽。

### 构建、测试与打包

构建和测试命令见上方 English 部分；平台打包入口位于 `packaging/`，三平台 CI 位于 `.github/workflows/ci.yml`。

当前已接入可选的 Kirigami 6.8.0。本机 Windows 构建可先运行
`scripts/Install-Kirigami.ps1`，再使用 `-DRECLIP_ENABLE_KIRIGAMI=ON`
配置；未安装 Kirigami 时项目会自动回退到 Qt Quick Controls 2 壳层。

请仅下载你有权保存的媒体。ReClipQt 不会绕过 DRM、付费墙、身份验证或平台访问限制。

### 许可证

使用 MIT 许可证，详见 [LICENSE](LICENSE) 和 [NOTICE](NOTICE)。
