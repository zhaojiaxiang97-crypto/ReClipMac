# Linux AppImage 打包

脚本依赖 Qt 的 `qt-cmake`、`linuxdeployqt` 和可执行的 `yt-dlp`、`ffmpeg`、`ffprobe`。推荐在目标发布基线或更老的 Linux 发行版上构建，以避免生成的 AppImage 依赖更新的 glibc。

从仓库根目录执行：

```bash
RECLIP_QT_ROOT="$HOME/Qt/6.8.3/gcc_64" \
RECLIP_LINUXDEPLOYQT="$HOME/bin/linuxdeployqt" \
RECLIP_TOOL_BIN="$HOME/reclip-tools/bin" \
  bash packaging/linux/package-appimage.sh Release
```

构建文件默认放在 `.build/package-linux-Release`，输出为 `.artifacts/linux/ReClip-Release-x86_64.AppImage`。脚本拒绝覆盖已有 AppDir 或 AppImage；应用、Qt/QML、平台插件、下载工具和许可证会写入 AppImage。发布前应在无 Qt 开发环境的干净桌面会话中执行：启动、工具检测、媒体解析、MP4/MP3 下载和文件打开 smoke test。

AppImage 只解决应用分发，不替代目标发行版的安全更新。当前发布基线建议记录为构建机发行版、架构、glibc 版本和 Qt 版本。
