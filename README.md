# Video Downloader

[English](#english) | [简体中文](#简体中文)

Video Downloader is a cross-platform desktop media downloader built with Qt 6
and QML. It uses `yt-dlp` to inspect public media links and FFmpeg to download
video or extract audio. The project is being migrated from the original
[ReClipMac](https://github.com/zhaojiaxiang97-crypto/ReClipMac) implementation.

The product name is now **Video Downloader**. Some repository paths, package
file names, QML module names, and CMake variables still use `ReClip` or
`ReClipQt` while the migration is being completed. Those names are internal
compatibility identifiers and do not change the product name shown to users.

## English

### What it does

- Reads public media URLs with `yt-dlp`.
- Downloads MP4 video or extracts MP3 audio with FFmpeg.
- Lets you choose from the available video formats and quality levels.
- Shows download progress, speed, remaining time, and queue status.
- Lets you cancel, retry, reveal, or remove a download.
- Saves download-folder, tool-path, and interface-theme preferences locally.
- Provides light and dark themes, clipboard paste, and drag-and-drop URL input.
- Uses an adaptive QML interface and can use KDE Kirigami when it is installed.

### Current platform scope

The current CI produces desktop packages for Windows, macOS, and Linux. An
experimental Android arm64-v8a build is also available for shell, URL intake,
SAF export-directory, and runtime-diagnostics validation on a real device.
Android media downloading is still experimental, but the arm64-v8a build can
bundle the maintained FFmpegKit runtime and the yt-dlp Android runtime for
real-device validation. Background execution, ABI coverage, licensing review,
and signed release packaging are still being finalised.

### Requirements

- Qt 6.8 or later, including Qt Quick, QML, Qt Quick Controls 2, and Shader Tools.
- CMake 3.21 or later and a C++17-compatible compiler.
- Desktop: `yt-dlp`, `ffmpeg`, and `ffprobe` available as executable tools.
- Android: the optional full runtime build bundles the maintained FFmpegKit
  AAR and yt-dlp Android AAR; a dependency-free build still checks its private
  `files/bin` directory (and optional APK `assets/bin` files) and reports the
  missing runtime path in Settings.
- Optional adaptive shell: KDE Kirigami 6.8.0 and Extra CMake Modules 6.8.0.

### Build and test

From the repository root, configure and build with the Qt kit you want to use.

Windows with Visual Studio:

```powershell
cmake -S . -B .build/windows -G "Visual Studio 17 2022" -A x64 -DBUILD_TESTING=ON
cmake --build .build/windows --config Release
ctest --test-dir .build/windows -C Release --output-on-failure
```

To enable the optional Kirigami shell on Windows, install the pinned local
dependency first:

```powershell
powershell -ExecutionPolicy Bypass -File scripts/Install-Kirigami.ps1
cmake -S . -B .build/windows-kirigami -G "Visual Studio 17 2022" -A x64 -DRECLIP_ENABLE_KIRIGAMI=ON -DBUILD_TESTING=ON
cmake --build .build/windows-kirigami --config Release
ctest --test-dir .build/windows-kirigami -C Release --output-on-failure
```

If Kirigami is not available, CMake automatically uses the Qt Quick Controls 2
shell from `qml/Main.qml`. Set `-DRECLIP_ENABLE_KIRIGAMI=OFF` to make that
fallback explicit.

macOS or Linux:

```bash
qt-cmake -S . -B .build/desktop -DCMAKE_BUILD_TYPE=Release -DBUILD_TESTING=ON
cmake --build .build/desktop --config Release
ctest --test-dir .build/desktop --output-on-failure
```

### Android (experimental)

The Android path currently targets Qt 6.8.3, `arm64-v8a`, Android API 34 for
the NDK toolchain, and a minimum Android API 28. The repository includes a
repeatable PowerShell build entry point; it keeps generated files under
`.build/` and does not change the desktop build commands above.

```powershell
powershell -ExecutionPolicy Bypass -File scripts/android/Build-Android.ps1 `
  -Abi arm64-v8a -BuildType Debug `
  -WithYtDlpAndroid -WithAndroidFfmpegKit
```

The script expects Qt's host kit and Android kit, Android SDK command-line
tools, platform-tools, an Android platform, NDK `26.1.10909125`, CMake, Ninja,
and JDK 17. The current Android shell uses the Qt Quick Controls 2 mobile
fallback and accepts `ACTION_SEND` text and HTTP(S) `ACTION_VIEW` links.
Completed media is kept in the app-private working directory first; users can
choose a persistent Android Storage Access Framework export directory from
Settings. The app also routes open/share actions through Android intents.
Kirigami remains an optional desktop shell for now; its Android dependency and
packaging strategy will be evaluated separately. Android runtime binaries can
be staged with the switches above, while long-running background downloads,
notifications, ABI coverage, and signed release packaging remain separate
work items, so a generated APK is not yet a release-ready mobile build.

Generated files stay out of the repository root. `.build/` contains local CMake
build trees and `.artifacts/` contains packaged applications. Both directories
are ignored by Git.

### Packaging

- Windows portable package: `packaging/windows/package.ps1`
- macOS application bundle: `packaging/macos/package.sh`
- Linux AppImage: `packaging/linux/package-appimage.sh`
- Cross-platform CI: `.github/workflows/ci.yml`

Each packaging script expects a working Qt installation and executable
`yt-dlp`, `ffmpeg`, and `ffprobe` binaries. See the README in the relevant
`packaging/` directory for platform-specific variables and release checks.

### Source layout

```text
CMakeLists.txt
src/                    C++/Qt application logic
qml/                    QML interface, themes, and reusable components
android/                Android manifest, activity bridge, and resources
tests/                  Qt Test coverage
packaging/              Platform packaging scripts and notices
scripts/                Dependency bootstrap scripts
.github/workflows/      Cross-platform CI
.build/                 Local CMake build trees (generated and ignored)
.artifacts/             Packaged applications (generated and ignored)
```

### Legal notice

Only download media that you have permission to save. Video Downloader does
not bypass DRM, paywalls, authentication, or platform access restrictions.

### Licence

This project is released under the MIT Licence. See [LICENSE](LICENSE) and
[NOTICE](NOTICE).

## 简体中文

### 项目简介

**Video Downloader（视频下载工具）** 是一个使用 Qt 6 和 QML 构建的跨平台
桌面媒体下载器。它使用 `yt-dlp` 解析公开媒体链接，并使用 FFmpeg 下载视频
或提取音频。项目正在从最初的
[ReClipMac](https://github.com/zhaojiaxiang97-crypto/ReClipMac) 实现迁移而来。

当前产品名称已经改为 **Video Downloader**。在迁移完成前，仓库目录、部分
打包文件名、QML 模块名和 CMake 变量中仍可能出现 `ReClip` 或 `ReClipQt`。
这些名称只是内部兼容标识，不影响用户看到的产品名称。

### 主要功能

- 使用 `yt-dlp` 解析公开媒体链接。
- 使用 FFmpeg 下载 MP4 视频或提取 MP3 音频。
- 从可用格式和清晰度中选择输出质量。
- 显示下载进度、速度、剩余时间和队列状态。
- 支持取消、重试、打开文件位置和移除下载任务。
- 在本地保存下载目录、工具路径和界面主题设置。
- 支持浅色/深色主题、从剪贴板粘贴链接，以及拖拽链接输入。
- 使用自适应 QML 界面；安装 KDE Kirigami 后可以启用 Kirigami 壳层。

### 当前支持范围

当前 CI 会生成 Windows、macOS 和 Linux 桌面端软件包。Android `arm64-v8a`
实验构建也已经可以用于真机验收界面、链接入口、SAF 导出目录和运行时诊断。
Android 媒体下载暂未达到发布条件，因为 yt-dlp/FFmpeg 的运行时分发方案和
后台执行模型仍在确定中。

### 环境要求

- Qt 6.8 或更高版本，包含 Qt Quick、QML、Qt Quick Controls 2 和 Shader Tools。
- CMake 3.21 或更高版本，以及支持 C++17 的编译器。
- 桌面端：需要可执行的 `yt-dlp`、`ffmpeg` 和 `ffprobe`。
- Android：当前不会自动打包媒体运行时；应用会优先检查私有目录
  `files/bin`（以及可选的 APK `assets/bin` 文件），缺失时在设置页显示实际路径。
- 可选的自适应界面依赖：KDE Kirigami 6.8.0 和 Extra CMake Modules 6.8.0。

### 构建与测试

请在仓库根目录执行命令，并根据实际使用的 Qt Kit 选择配置方式。

Windows 和 Visual Studio：

```powershell
cmake -S . -B .build/windows -G "Visual Studio 17 2022" -A x64 -DBUILD_TESTING=ON
cmake --build .build/windows --config Release
ctest --test-dir .build/windows -C Release --output-on-failure
```

如果要在 Windows 上启用可选的 Kirigami 壳层，请先安装固定版本的本地
依赖：

```powershell
powershell -ExecutionPolicy Bypass -File scripts/Install-Kirigami.ps1
cmake -S . -B .build/windows-kirigami -G "Visual Studio 17 2022" -A x64 -DRECLIP_ENABLE_KIRIGAMI=ON -DBUILD_TESTING=ON
cmake --build .build/windows-kirigami --config Release
ctest --test-dir .build/windows-kirigami -C Release --output-on-failure
```

如果没有安装 Kirigami，CMake 会自动使用 `qml/Main.qml` 中的 Qt Quick
Controls 2 界面。也可以通过 `-DRECLIP_ENABLE_KIRIGAMI=OFF` 明确关闭
Kirigami。

macOS 或 Linux：

```bash
qt-cmake -S . -B .build/desktop -DCMAKE_BUILD_TYPE=Release -DBUILD_TESTING=ON
cmake --build .build/desktop --config Release
ctest --test-dir .build/desktop --output-on-failure
```

Android（实验性）：

当前 Android 构建目标是 Qt 6.8.3、`arm64-v8a`、Android API 34 工具链，
最低支持 API 28。仓库提供可重复执行的 PowerShell 构建入口，生成文件统一
放在 `.build/` 中，不会改变桌面端构建命令。

```powershell
powershell -ExecutionPolicy Bypass -File scripts/android/Build-Android.ps1 `
  -Abi arm64-v8a -BuildType Debug `
  -WithYtDlpAndroid -WithAndroidFfmpegKit
```

脚本需要 Qt 主机 Kit 和 Android Kit、Android SDK、platform-tools、Android
平台、NDK `26.1.10909125`、CMake、Ninja 以及 JDK 17。当前 Android 壳层使用
Qt Quick Controls 2 移动端回退布局，支持从其他应用接收 `ACTION_SEND` 文本和
HTTP(S) `ACTION_VIEW` 链接。已下载文件会先保存在应用私有工作目录，用户可以
在设置中通过 Android Storage Access Framework 选择持久化导出目录，打开文件、
打开目录和分享文件会走 Android 系统 Intent。

Android 的 yt-dlp/FFmpeg 运行时已经可以通过上述构建参数打入 APK；长时间后台下载、
ABI 覆盖、通知和正式签名仍在规划中，因此当前 APK 仅用于开发与真机验收，
不是可发布的移动版本。

生成文件不会放在仓库第一层目录中：`.build/` 用于保存本地 CMake 构建树，
`.artifacts/` 用于保存打包产物；这两个目录都已加入 Git 忽略规则。

### 打包入口

- Windows 便携版：`packaging/windows/package.ps1`
- macOS 应用包：`packaging/macos/package.sh`
- Linux AppImage：`packaging/linux/package-appimage.sh`
- 跨平台 CI：`.github/workflows/ci.yml`

每个打包脚本都需要可用的 Qt 安装，以及可执行的 `yt-dlp`、`ffmpeg` 和
`ffprobe`。平台相关的变量和发布前检查请参阅对应 `packaging/` 目录中的
说明文件。

### 源码目录

```text
CMakeLists.txt
src/                    C++/Qt 业务逻辑
qml/                    QML 界面、主题和可复用组件
tests/                  Qt Test 测试
packaging/              各平台打包脚本和许可证说明
scripts/                依赖安装与引导脚本
.github/workflows/      跨平台 CI
.build/                 本地 CMake 构建树（自动生成并忽略）
.artifacts/             打包产物（自动生成并忽略）
```

### 使用限制

请只下载你有权保存的媒体内容。Video Downloader 不会绕过 DRM、付费墙、
身份验证或平台访问限制。

### 许可证

本项目使用 MIT Licence，详见 [LICENSE](LICENSE) 和 [NOTICE](NOTICE)。
