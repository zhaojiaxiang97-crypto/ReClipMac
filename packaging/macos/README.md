# macOS `.app` 打包

从仓库根目录执行：

```bash
bash packaging/macos/package.sh Release
```

脚本使用 `qt-cmake` 和 `macdeployqt` 构建并部署 Qt framework、QML 模块和平台插件，构建文件默认放在 `.build/package-macos-Release`，输出到 `.artifacts/macos/ReClip-Release.app`。可以通过 `RECLIP_QT_ROOT` 指定 Qt 安装目录，通过 `RECLIP_TOOL_BIN` 指定包含 `yt-dlp`、`ffmpeg` 和 `ffprobe` 的目录。脚本拒绝覆盖已有输出目录。

工具会放在 `.app/Contents/Resources/bin`，应用会优先从这个目录检测它们，因此运行时不依赖开发机的 PATH。脚本会让 `macdeployqt` 继续收集 FFmpeg 可执行文件引用的动态库；`yt-dlp` 应使用 standalone macOS 可执行文件或其他自包含构建。实际发布前应在干净 macOS 用户账户中验证工具检测、媒体解析、MP4/MP3 下载和 Finder 打开文件夹。

签名和公证：

```bash
RECLIP_CODESIGN_IDENTITY="Developer ID Application: Example" \
  bash packaging/macos/package.sh Release

RECLIP_CODESIGN_IDENTITY="Developer ID Application: Example" \
RECLIP_NOTARY_PROFILE="reclip-notary" \
  bash packaging/macos/package.sh Release
```

签名身份、公证 profile、最低 macOS 版本和 entitlements 应由发布账号在 macOS Runner 上配置；仓库不保存证书、私钥或 Apple 账号凭据。
