# yt-dlp 内嵌运行时：Windows MVP

更新：2026-09-12。对应主计划的 T0/T1、T2 基础链路和受控 HLS/DASH VOD 子集；不是全部站点、协议和平台均已完成。

## 当前行为

- `YtDlpService` 统一桌面媒体解析、单一格式下载和 FFmpeg SDK 前置解析的调用，提供请求 ID、超时、取消确认、版本查询和错误结果。
- 开启 `RECLIP_ENABLE_YTDLP_SDK`、未指定命令行路径时，应用加载私有 CPython，通过 Python API 调用 yt-dlp，不通过 `python.exe` / `yt-dlp.exe` 执行解析。
- 下载 MVP 使用 yt-dlp 解析；单一合并流优先走内嵌 yt-dlp Python 原生下载器，失败时在严格内嵌模式回退到 Qt HTTP(S)，随后由 FFmpeg SDK 完成 MP4 封装或 MP3 转码。已验证 MP4/MP3、独立双流、队列，以及受控 HLS/DASH VOD 播放列表的 SDK 网络输入。
- 内嵌 yt-dlp 原生下载器只接受一个已解析媒体流，拒绝 `requested_formats` 多流合并、DRM 和依赖外部后处理的场景；多流合并仍由宿主编排和 FFmpeg SDK 接管。
- yt-dlp 返回 `m3u8`/`dash`/分段协议时，已识别为分段输入并交给 FFmpeg SDK 的 `libavformat` 读取播放列表和分片；当前通过的是本地 HLS/DASH VOD fixture，不能据此宣称所有 HLS/DASH 网站、直播或加密流均支持。
- `FfprobeService` 是 FFmpeg SDK 内的显式媒体探测入口，使用 `libavformat`、`libavcodec` 和 `libavutil` 提供 ffprobe 的容器、时长、大小、流类型、编码、采样率和声道信息；SDK 模式下工具诊断不会启动 `ffprobe.exe`。只有兼容模式或用户显式配置外部路径时才保留命令行 ffprobe。
- 内嵌模式不自动回退外部命令。明确设置非空 `yt-dlp` 自定义可执行路径，会选择旧进程兼容路径；清空恢复内嵌模式。失败的运行时初始化不会自动搜索 PATH。
- Android Chaquopy 和 FFmpegKit 路径保留；JNI 现在与桌面服务使用同一类终态协议：请求 ID、结构化 JSON 产物、错误码和错误消息。取消会等待 Android worker 离开嵌入式 yt-dlp/FFmpeg 调用后再回传终态。本轮生成了独立协议测试 APK，但小米设备端的 USB 安装确认未完成，因此不把它算作本轮真机功能验收。

## 固定依赖

`runtime/python/dependencies.json` 固定：CPython 3.13.15（PSF NuGet）、yt-dlp wheel 2026.8.19、certifi 2026.7.22。yt-dlp 自报版本为 `2026.08.19`。

下载脚本对 NuGet 包校验目录元数据发布的 SHA-512，对 wheel 校验 PyPI 发布的 SHA-256。只在构建时解包，不改系统 Python，不运行首次启动安装或在线更新。

```powershell
.\scripts\Fetch-PythonRuntime.ps1
# 如果开发机需要代理，可显式传入 -Proxy http://127.0.0.1:7897
```

开发包位于 `.third_party/python/windows-x64/3.13.15/tools`。首次下载失败的文件会保留，校验失败不会继续解包；不同/不完整输出目录不会被自动覆盖，可指定新的 `-OutputDirectory`。

## 构建与打包

当前桌面 SDK 构建选项仅开放 Windows x64；没有启用时，Windows/macOS/Linux 原命令行配置仍可构建。Android 不通过该选项链接第二份 Python。

```powershell
cmake -S . -B .build/windows-ytdlp-sdk -G "Visual Studio 17 2022" -A x64 `
  -DCMAKE_PREFIX_PATH=D:/QT/6.8.3/msvc2022_64 `
  -DRECLIP_ENABLE_KIRIGAMI=OFF `
  -DRECLIP_ENABLE_FFMPEG_SDK=ON -DRECLIP_ENABLE_YTDLP_SDK=ON
cmake --build .build/windows-ytdlp-sdk --config Release --parallel 4
ctest --test-dir .build/windows-ytdlp-sdk -C Release --output-on-failure

$env:RECLIP_QT_ROOT = 'D:\QT\6.8.3\msvc2022_64'
.\packaging\windows\package.ps1 -Configuration Release -EnableYtDlpSdk
```

示例 Qt 路径需按开发机调整，CTest 需能找到对应 Qt DLL。`-EnableYtDlpSdk` 同时开启 FFmpeg SDK，默认输出 `.artifacts/windows/ReClip-Release-ytdlp-sdk`；输出目录已存在时脚本拒绝覆盖。自定义开发包通过 CMake `-DRECLIP_PYTHON_ROOT=...` 或打包脚本读取的 `RECLIP_PYTHON_ROOT` 环境变量指定。

发布布局：

```text
ReClip.exe
python313.dll / python3.dll
FFmpeg SDK DLLs / Qt DLLs及插件
runtime/python/
  Lib/                       # 标准库与锁定的 site-packages
  DLLs/                      # Python 扩展及其依赖
  LICENSE.txt
  dependencies.json
licenses/Python-dependencies.json
```

Python 适配层作为 Qt 资源编入程序；发布运行时不复制 `python.exe`、`pythonw.exe`、pip、ensurepip 或开发工具。该测试包不携带 `yt-dlp.exe`、`ffmpeg.exe`、`ffprobe.exe`，也不携带 EJS、QuickJS 或 curl-cffi。体积与完整平台分发仍需专门评估；当前 `cmake --install` 并非完整 Python/Qt 发布入口，应使用上述打包脚本。

## 生命周期和安全边界

- 单个进程级解释器在专用线程初始化、串行运行请求并最终销毁；调用间释放 GIL，Qt 回调只传递值。
- `PyConfig_InitIsolatedConfig` 配合显式私有标准库/扩展路径，禁用 site 导入及字节码写入，忽略 `PYTHONHOME`、`PYTHONPATH` 和用户 Python 包。固定适配层禁用用户插件发现。
- Python 审计钩子拒绝子进程执行，关闭外部 JS/远程组件；显式指定格式，避免 yt-dlp 默认格式选择触发 FFmpeg 可用性探测。这是应用防线，不是 OS 安全沙箱。
- 取消使用原子标记，等待调用退出后再报告取消；Qt 超时只发出取消请求，不能强杀 Python 线程。网络读取最长单次 5 秒，适配检查点限制累计等待；复杂提取器的不可中断计算仍需后续压力/挂起验证。
- 内嵌下载拒绝覆盖现有目标；临时输入使用独立随机文件名，FFmpeg 发布时同样禁止覆盖，失败记录不认领已有文件。进程兼容后端保持其历史覆盖策略。
- 日志错误中的 URL 被隐藏；Cookie/代理完整跨网络栈传递及更广泛的敏感字段审计仍待实现。

## 验证入口

```powershell
.\.third_party\python\windows-x64\3.13.15\tools\python.exe -I -B tests/python_adapter.py

.\scripts\Test-EmbeddedYtDlp.ps1 `
  -Executable .build/windows-ytdlp-sdk/Release/ReClipEmbeddedYtDlpTest.exe `
  -QtBin D:/QT/6.8.3/msvc2022_64/bin `
  -EvidenceDirectory .artifacts/ytdlp-sdk/release
```

该脚本默认使用 Windows 进程创建事件，而非轮询进程列表。当前执行环境订阅 `Win32_ProcessStartTrace` 返回 `Access denied`；本轮没有提升权限或宣称 OS 级验收通过。可显式使用 `-SkipProcessTrace` 只运行功能测试，其 JSON 记录 `processCreationTraceAvailable=false`、`childCount=null`。

`ReClipEmbeddedYtDlpTest` 使用真实固定 yt-dlp 和本地 HTTP fixture，覆盖版本/隔离配置、媒体解析、单一格式原生下载、非法 URL、404 与签名 URL 隐藏、开始前及读取期间取消、超时、GUI 事件循环、迟到回调、重复调用、MP4/MP3 输出探测、同名文件保护、受控 HLS/DASH VOD、混合队列与持久化。已有 fake yt-dlp 测试继续覆盖进程兼容、FFmpeg SDK 双流和 HLS/DASH 网络输入路径；不能将 fake 双流测试误报成真实网站双流验收。

## 仍未完成

- Android 的请求/结果协议已对齐，仍需在设备端验证取消后的 Python worker 实际退出时序；跨平台共享 Python 包仍未实现。
- yt-dlp Python 原生下载器目前只覆盖单一已解析格式；多格式下载策略、YouTube EJS/内嵌 JS、鉴权和更广泛真实网站仍待补。HLS/DASH 目前只验证了受控 VOD fixture，直播、加密和真实站点矩阵仍待补。
- 完全无开发环境的独立干净机验证、OS 级子进程创建观测、长时间压力、异常网络/磁盘完整矩阵。
- macOS/Linux 内嵌发行、正式签名和自动化依赖升级验收。

## 本轮执行记录（2026-09-12）

| 验证 | 结果 |
| --- | --- |
| Windows Release 完整 CTest | 多轮 10/10 通过，包括新内嵌端到端测试和同名输出保护 |
| Windows Debug 内嵌端到端测试 | 1/1 通过；未声称全部 Debug 测试已执行 |
| 受控 HLS/DASH VOD | 内嵌 yt-dlp 解析 m3u8/MPD，FFmpeg SDK 在进程内读取播放列表和媒体片段并输出 MP4；Release/Debug 内嵌端到端测试均覆盖 |
| 关闭两个 SDK 的旧进程配置 | Release 构建与 CTest 6/6 通过 |
| Python 适配层测试 | 5/5 通过，覆盖探测、取消、拒绝子进程、禁用用户插件和 URL 隐藏 |
| FFprobe SDK facade | `FfprobeService` 通过 FFmpeg SDK 对本地媒体完成探测；版本探针和媒体探测测试通过，SDK 模式不执行 `ffprobe.exe` |
| 内嵌 yt-dlp 原生单流下载 | 真实 yt-dlp + 本地 HTTP fixture 写入指定文件，验证输出大小和同名目标拒绝；桌面 DownloadManager 直链 MP4/MP3 使用该路径 |
| Android JNI 结构化协议 | arm64-v8a AAR/FFmpegKit Debug APK 编译、Java 编译和二次 Gradle 打包通过；结果包含 `path/bytes/format/backend`，错误包含统一错误码；真机安装被设备端 USB 确认拦截 |
| 标准库缺失 | 独立目录内的测试程序返回可诊断 `runtime-error`，预期错误测试退出码 0 |
| 包内运行时测试 | 复制便携包到独立验证目录，PATH 仅包含该目录及 Windows 系统目录；无效 PYTHONHOME/PYTHONPATH 不影响端到端测试，退出码 0 |
| 实际应用启动 | 发布包 offscreen 冷启动运行 5 秒，stderr 为空；加载的 Python、Qt Core、libavformat 均来自发布目录；随后关闭本次测试实例 |
| 最新原生单流/HLS/DASH/FFprobe SDK 便携包启动 | `.artifacts/windows/ReClip-Release-ytdlp-ffprobe-sdk-settings-clean` 中的 `ReClip.exe` 在无效 PYTHONHOME/PYTHONPATH、仅包内 PATH 的 offscreen 冷启动运行 5 秒，stderr 为空；设置页不再包含工具诊断，manifest 标记 `ffprobeBackend=embedded-sdk`，包内没有 `ffprobe.exe` |
| Android arm64 | 协议测试包的 C++/QML、Java、AAR 和 FFmpegKit 打包通过；安装被小米设备端 USB 确认拦截，未把本轮协议变更算入真机功能验收 |
| OS 进程创建事件 | 当前权限不足，未通过；Python 层拒绝子进程的测试不替代该项 |

最新 Windows 产物为 `.artifacts/windows/ReClip-Release-ytdlp-ffprobe-sdk-settings-clean/ReClip.exe`；目录约 244.57 MiB（256,451,816 字节，3,016 个文件），唯一发布 `.exe` 为主程序。主程序 SHA-256：`D1C4C7AAADF488F242DAAEBC3929106501965632C5DFC91B321B0C9D5B0110`。manifest 标记 `ffprobe=embedded-sdk/libavformat`、`ffprobeBackend=embedded-sdk`，包内没有 `ffprobe.exe`；设置页不再包含工具诊断或外部工具路径编辑。该包已复制到隔离目录完成内嵌端到端测试、FFprobe SDK 输出校验和无效 Python 环境下的 offscreen 冷启动。测试 fixture 只放在隔离验证目录，不进入发布包。Android 协议测试包为 `.build/android-arm64-protocol/android-build/build/outputs/apk/debug/android-build-debug.apk`，包名 `com.reclip.videodownloader.protocol`，SHA-256：`74EA300F26854220CB1209061085E8308B65F7246F310AEBB069450C3E27561B`；它只作为独立验证产物，不覆盖现有应用。此前 HLS/DASH 包 `.artifacts/windows/ReClip-Release-ytdlp-hls-sdk`、基础包 `.artifacts/windows/ReClip-Release-ytdlp-sdk`、上一版 FFprobe SDK 包 `.artifacts/windows/ReClip-Release-ytdlp-ffprobe-sdk` 和前一版最终包 `.artifacts/windows/ReClip-Release-ytdlp-ffprobe-sdk-final` 仍保留作对照。

包内测试证据位于 `.artifacts/ytdlp-sdk/packaged-check-native/`，包括原生单流、HLS/DASH 日志及明确标注未进行 OS 进程观测的 `process-trace.json`；此前 HLS/DASH 证据位于 `.artifacts/ytdlp-sdk/packaged-check-hls/`。该验证仍在开发机进行，不等于独立干净机验收。短 fixture 的 AAC 解码出现时间戳警告，但输出探测与测试通过；后续还需覆盖长媒体的完整解码与音画同步。

技术依据：[yt-dlp 嵌入接口](https://github.com/yt-dlp/yt-dlp#embedding-yt-dlp)、[CPython 嵌入接口](https://docs.python.org/3.13/extending/embedding.html)、[隔离初始化](https://docs.python.org/3.13/c-api/init_config.html)。
