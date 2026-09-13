# Android 当前工作树真机回归（2026-09-12）

## 范围与状态

本轮继续验证内置 Android FFmpegKit 和下载队列，从当前工作树重新构建 APK。
设备是 Xiaomi 24094RAD4C，Android 14 / API 34 / arm64-v8a。
旧包 `com.reclip.videodownloader` 已备份且保留；本机缺少旧包的调试签名密钥，
因此使用独立包 `com.reclip.videodownloader.dev`，显示名称为 **Video Downloader Dev**。

- [x] 安装并校验 Android 工具链和固定版本运行时。
- [x] 当前源码 CMake 配置、C++/QML arm64 编译通过。
- [x] APK 打包与签名校验，约 59 MiB，minSdk 28 / targetSdk 35 / arm64-v8a。
- [x] 手机确认安装后，ADB 返回 `Success`；新旧应用并存，没有卸载、清空或覆盖旧应用。
  此前的 `INSTALL_FAILED_USER_RESTRICTED` 已解除，拦截点是小米安全中心的 USB 安装确认。
- [x] 单次 MP3 下载、内置 FFmpeg 转换日志及输出音频校验。
- [x] 两项混合格式队列顺序执行、前台服务启动/退出及文件校验。
- [x] 横竖屏、后台返回、强制停止后重启和已完成任务持久化。

## 真机验收结果

设备已安装 APK 的 SHA-256 与本机交付 APK 完全一致：
`2DB8B8F45FFD7DEA878FC86349F4D0408EE8DE1314000881B96E80785C7662AF`。
因此以下结果来自**当前工作树构建的 Dev 包**，不是此前的旧包。

| 项目 | 实测结果 |
| --- | --- |
| 冷启动与工具初始化 | 主界面、设置页正常显示，yt-dlp/FFmpeg 均就绪 |
| 单次 MP3 | `clip.mp4` 经 AAC → `libmp3lame` 转码；输出 13,722 bytes、3.018594 秒、44.1 kHz、单声道 MP3 |
| 两项队列 | 通过 QML 界面加入 `queuea.mp4`（输出 MP3）、`queueb.mp4`（输出 MP4），两项最终均显示下载完成 |
| 顺序执行证据 | 第一项于 15:39:23 开始请求，FFmpeg 于 15:39:28.599 返回成功；第二项请求于 15:39:29 才开始 |
| 前台服务 | 执行时 `isForeground=true`、通知 ID 4101；全部完成后 `dumpsys activity services` 返回空 |
| 文件完整性 | 队列 MP3 可完整解码；MP4 为 307,080 bytes，SHA-256 与源文件一致，完整音视频解码通过 |
| 旋转 | 横屏 UI 层级 `rotation=1`，截图无四色撕裂；结束后恢复 `wm user-rotation free` 和竖屏 |
| 后台恢复 | Home 后再打开，PID 保持 24114，队列状态保留 |
| 进程重建 | 无活动下载时强制停止 Dev 包，再启动得到新 PID 24997；两项完成状态与文件仍保留 |
| 崩溃检查 | 三个测试进程的日志未匹配 Java/native 崩溃、缺失 native library 或 Java 方法签名错误 |

### 内置库调用的证据

- Java 日志记录 `FFmpeg MP3 session finished: success=true, error=`。
- 日志包含 `aac (native) -> mp3 (libmp3lame)` 的实际编码映射。
- 应用进程 `/proc/<pid>/maps` 显示从 APK 安装目录加载
  `libffmpegkit.so`、`libavcodec.so`、`libavformat.so` 和 `libc++_shared.so`。
- 这与 Android bridge 的 FFmpegKit JNI 调用路径一致，验证的是进程内库转换，
  不是仅检查工具存在或直接复制 MP4。

### 可查看的结果

文件均在 `.artifacts/android-current/`：

- `final-queue.png`、`queue-complete.png`：两项任务完成，以及重启后状态保留。
- `mp3-complete.png`、`landscape.png`、`restarted.png`：转换、旋转与冷启动截图。
- `device-clip.mp3`、`device-queuea.mp3`、`device-queueb.mp4`：从手机取回的真实输出。
- `mp3-logcat.log`、`queue-logcat.log`、`lifecycle-logcat.log`、`restart-logcat.log`：应用日志。
- `native-libraries.log`、`http-server.log`：进程内共享库映射与受控 HTTP 请求时序。

本轮只使用本机生成、经 `adb reverse` 提供的测试素材，没有调用外部站点账号。

## 本机工具链

| 组件 | 版本 / 路径 |
| --- | --- |
| Qt Host | 6.8.3，`D:\QT\6.8.3\msvc2022_64` |
| Qt Android | 6.8.3，`D:\QT\6.8.3\android_arm64_v8a` |
| JDK | Temurin 17.0.20.1+1，`.third_party/java/jdk-17.0.20.1+1` |
| Android SDK | `.third_party/android-sdk` |
| SDK Platform / Build Tools | API 35 rev 2 / 35.0.0 |
| NDK / C++ API | 26.1.10909125 (r26b) / android-34 |
| Gradle / Android Gradle Plugin | 8.10 / 8.6.0 |
| yt-dlp Android / FFmpegKit | 固定 2.0.2 / full 8.1.7，校验脚本验证 SHA-256 |

Qt 目标包来自 Qt 官方仓库；JDK、SDK、NDK 和 Gradle 均验证官方校验值。
本机下载需使用系统代理；只为下载和构建进程设置代理，没有修改系统代理。
构建脚本优先显式 `-JavaHome`、有效 `JAVA_HOME` 或项目内 JDK 17。
Java 临时目录和 Gradle 缓存分别放在 `.scratch/android-java-tmp` 和
`.third_party/gradle-cache`，避免 Windows 临时目录导致 Java NIO 回环连接失败。
脚本禁用持久 Gradle daemon，避免 CMake 完成后后台进程仍占用 PowerShell
输出管道而导致脚本不退出。

## 复现构建

在仓库根目录执行（本机已缓存依赖）：

```powershell
pwsh -NoProfile -File scripts/android/Build-Android.ps1 `
  -QtRoot D:\QT `
  -AndroidSdkRoot F:\develop\.third_party\android-sdk `
  -JavaHome F:\develop\.third_party\java\jdk-17.0.20.1+1 `
  -BuildDir F:\develop\.build\android-arm64-current-dev `
  -ApplicationId com.reclip.videodownloader.dev `
  -AppName "Video Downloader Dev" `
  -WithYtDlpAndroid -WithAndroidFfmpegKit -Parallel 4
```

默认包名不变；只有传入 `-ApplicationId` 才生成并存测试包。
Android 的 FFmpegKit 通过 JNI 在应用进程内调用，独立于桌面
`RECLIP_ENABLE_FFMPEG_SDK` 开关；Android 构建不应指向 Windows FFmpeg SDK。

## 测试素材与证据

- 上轮旧包测试的 5,222-byte fixture 实际为 **0.4 秒**，不是 3 秒；计划文档已修正。
- 本轮新生成 `.artifacts/android-current-3s.mp4`：3.000 秒、320×180、
  MPEG-4 视频 + AAC 44.1 kHz 音频、307,080 bytes。
- 旧 APK 备份：`.artifacts/android-device-before-current-build.apk`。
- 当前编译日志：`.artifacts/android-current-build.log`。
- 可安装产物：`.artifacts/android-current/VideoDownloader-Dev-arm64-debug.apk`。
  大小 61,911,906 bytes；SHA-256：
  `2DB8B8F45FFD7DEA878FC86349F4D0408EE8DE1314000881B96E80785C7662AF`。
- 修正 Gradle daemon 设置后，构建脚本再次完整运行通过并正常退出。
- 构建中的非致命警告：其他平台/Kirigami QML imports 未解析（Android 不启用这些壳层）；
  Qt 与 FFmpegKit 都包含 `libc++_shared.so`，AGP 8.6 当前选择应用提供的 NDK 版本。
  该组合已通过本台设备的两次 MP3 转换；重复共享库的打包警告仍需在升级 AGP 时处理。
- 已复跑桌面测试：SDK 构建 9/9、进程后端构建 6/6；需将 Qt 6.8.3
  `msvc2022_64/bin` 放在测试进程 PATH 首位，避免加载旧版 Qt DLL。
- 测试结束后 HTTP 服务器已停止，本轮 `tcp:18080` reverse 映射已移除，旋转设置已恢复。
  Dev 包和示例下载保留在手机上供用户查看。
- 工具链下载阶段的临时分片清理命令被自动审批拦截（未提供具体原因），
  下载归档及分片缓存暂时保留，不影响构建结果。

## 已观察到的限制与未覆盖项

- MP3 转换后，原始 MP4 仍留在应用私有下载目录；后续可完善中间文件清理策略。
- 本轮 HTTP 直链预览显示“时长未知”和“暂无缩略图”，下载及转码成功；媒体预览信息仍可完善。
- UIAutomator 检查期间出现 Qt accessibility / QObject 线程归属警告；本轮没有功能阻断，
  不应将“无崩溃签名”理解为“完全没有警告”。
- 自动化输入期间有一次 Activity 销毁/前台切换，日志无崩溃签名；恢复测试包后继续完成验收。
- 下载过程中 UIAutomator 曾无法等待到 idle；该次过期 XML 已移除，队列结论以最终界面、
  真实文件、服务状态和 HTTP/FFmpeg 日志交叉验证。

本轮单台 arm64 真机测试不代表无 Vulkan 设备、其他 ABI、所有站点、长时间锁屏下载、
网络中断、取消/重试、分享导出权限或发布签名/AAB 已验收。
