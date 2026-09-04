# ReClipMac

ReClipMac is a native macOS media downloader powered by `yt-dlp` and `ffmpeg`. It runs locally without Flask, Docker, a browser, or a background web service.

ReClipMac 是一个原生 macOS 媒体下载工具。它直接在本机调用 `yt-dlp` 和 `ffmpeg`，不需要启动 Web 服务。

## Features

- Parse one or more media links.
- Download MP4 video or extract MP3 audio.
- Select available video quality.
- Show sequential queue progress, speed, and remaining time.
- Cancel, retry, reveal, or remove a download.
- Move downloaded and partial files to the macOS Trash when deleting a task.
- Store files only in the selected local directory.

## Requirements

- macOS 14 or later.
- Xcode 16 or a Swift 6 toolchain.
- Homebrew `yt-dlp` and `ffmpeg`.

Install the runtime tools:

```bash
brew install yt-dlp ffmpeg
```

## Build and run

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

## Source layout

```text
Package.swift
Sources/ReClipMac/
  ReClipMacApp.swift
  ContentView.swift
  DownloadManager.swift
  DownloadItem.swift
  ToolLocator.swift
```

## Usage and copyright

Only download media you have permission to save. ReClipMac does not bypass DRM, paywalls, authentication, or platform access restrictions.

This repository retains the history and MIT license of the original [ReClip](https://github.com/averygan/reclip) project. The current codebase is a native macOS rewrite; the previous Flask and Web UI implementation has been removed.

## License

MIT. See [LICENSE](LICENSE).
