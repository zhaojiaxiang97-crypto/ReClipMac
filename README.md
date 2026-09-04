# ReClipMac

[English](#english) | [简体中文](#简体中文)

## English

ReClipMac is a native macOS media downloader powered by `yt-dlp` and `ffmpeg`. It runs locally without Flask, Docker, a browser, or a background web service.

### Features

- Parse one or more media links.
- Download MP4 video or extract MP3 audio.
- Select available video quality.
- Show sequential queue progress, speed, and remaining time.
- Cancel, retry, reveal, or remove a download.
- Move downloaded and partial files to the macOS Trash when deleting a task.
- Store files only in the selected local directory.
- Display English or Simplified Chinese automatically based on the macOS preferred language.

### Requirements

- macOS 14 or later.
- Xcode 16 or a Swift 6 toolchain.
- Homebrew `yt-dlp` and `ffmpeg`.

Install the runtime tools:

```bash
brew install yt-dlp ffmpeg
```

### Build and run

From the repository root:

```bash
swift run ReClipMac
```

Swift Package Manager will compile the project and open the native macOS window.

To create a release executable:

```bash
swift build -c release
```

The executable is written to `.build/release/ReClipMac`.

You can also open `Package.swift` directly in Xcode and run the `ReClipMac` scheme.

### Source layout

```text
Package.swift
Sources/ReClipMac/
  ReClipMacApp.swift
  ContentView.swift
  DownloadManager.swift
  DownloadItem.swift
  ToolLocator.swift
  Localization.swift
  Resources/
    en.lproj/Localizable.strings
    zh-Hans.lproj/Localizable.strings
```

### Usage and copyright

Only download media you have permission to save. ReClipMac does not bypass DRM, paywalls, authentication, or platform access restrictions.

This repository retains the history and MIT license of the original [ReClip](https://github.com/averygan/reclip) project. The current codebase is a native macOS rewrite; the previous Flask and Web UI implementation has been removed.

### License

MIT. See [LICENSE](LICENSE).

## 简体中文

ReClipMac 是一个基于 `yt-dlp` 和 `ffmpeg` 的原生 macOS 媒体下载工具。所有功能都在本机运行，不需要 Flask、Docker、浏览器或后台 Web 服务。

### 功能

- 解析一个或多个媒体链接。
- 下载 MP4 视频或提取 MP3 音频。
- 选择可用的视频清晰度。
- 实时显示顺序下载队列的进度、速度和剩余时间。
- 支持取消、重试、在 Finder 中显示或删除下载任务。
- 删除任务时，将已下载文件和临时文件移到 macOS 废纸篓。
- 文件只保存在用户选择的本地目录。
- 根据 macOS 首选语言自动显示英文或简体中文。

### 环境要求

- macOS 14 或更高版本。
- Xcode 16 或 Swift 6 工具链。
- 通过 Homebrew 安装 `yt-dlp` 和 `ffmpeg`。

安装运行工具：

```bash
brew install yt-dlp ffmpeg
```

### 构建和运行

在仓库根目录执行：

```bash
swift run ReClipMac
```

Swift Package Manager 会编译项目并打开原生 macOS 窗口。

构建 Release 可执行文件：

```bash
swift build -c release
```

可执行文件位于 `.build/release/ReClipMac`。

也可以直接使用 Xcode 打开 `Package.swift`，然后运行 `ReClipMac` Scheme。

### 源码结构

```text
Package.swift
Sources/ReClipMac/
  ReClipMacApp.swift
  ContentView.swift
  DownloadManager.swift
  DownloadItem.swift
  ToolLocator.swift
  Localization.swift
  Resources/
    en.lproj/Localizable.strings
    zh-Hans.lproj/Localizable.strings
```

### 使用与版权

请仅下载你有权保存的媒体。ReClipMac 不会绕过 DRM、付费墙、身份验证或平台访问限制。

本仓库保留了原始 [ReClip](https://github.com/averygan/reclip) 项目的提交历史和 MIT 许可证。当前代码已经重写为原生 macOS 应用，旧的 Flask 和 Web UI 实现已被移除。

### 许可证

使用 MIT 许可证，详见 [LICENSE](LICENSE)。
