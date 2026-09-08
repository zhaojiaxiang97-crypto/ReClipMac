# Video Downloader / ReClipQt 跨平台改造计划

> 更新时间：2026-09-07
> 当前产品名：**Video Downloader**（视频下载工具）
> 原项目基础：[ReClipMac](https://github.com/zhaojiaxiang97-crypto/ReClipMac)
> 文件名保留 `ReClipQt` 是为了兼容历史路径；用户可见产品名以 Video Downloader 为准。

## 1. 改造目标

将原有项目逐步改造成基于 Qt 6/QML 的跨平台视频下载工具：

- 使用 QML/Qt Quick 构建现代化、响应式界面。
- 使用 C++/Qt 保留稳定的下载、解析和媒体处理能力。
- 支持 Windows、macOS 和 Linux 桌面端。
- 为后续 Android、iOS 等移动端目标保留 UI 和业务逻辑扩展空间。
- 使用 Kirigami 提供桌面端可选的自适应应用壳，并保留 Android/iOS 可用的 Qt Quick Controls 2 回退方案；逐步把共享组件替换为 Kirigami 原生组件。
- 通过统一的测试、打包和 CI 流程保证多平台构建质量。

## 2. 当前命名约定

| 范围 | 名称 | 状态 |
| --- | --- | --- |
| 用户看到的产品名 | **Video Downloader** | 已统一到 README、应用标题、侧边栏和打包元数据 |
| CMake 项目名 | `VideoDownloader` | 已更新 |
| QML 模块 URI | `ReClip` | 暂时保留，避免破坏已有导入和构建产物 |
| 可执行文件与部分产物路径 | `ReClip` | 暂时保留，作为兼容标识 |
| 历史仓库链接与版权说明 | `ReClipMac` / `ReClip` | 保留历史来源和归属信息 |

后续如果要彻底重命名 QML 模块、可执行文件、包名和 GitHub 仓库，还需要单独执行一次兼容性迁移，并同步更新安装路径、用户设置路径、CI 产物名和发布链接。

## 3. 阶段状态

### 阶段 A：基础迁移 —— 已完成

- [x] 移除原 macOS SwiftUI/native 平台实现。
- [x] 建立 Qt 6、CMake、C++/Qt 和 QML 工程结构。
- [x] 将下载、队列、媒体解析、工具检测和设置逻辑接入 Qt 后端。
- [x] 使用 Qt Quick Controls 2 搭建基础跨平台界面。
- [x] 配置 Windows、macOS、Linux 构建入口。

### 阶段 B：目录和依赖整理 —— 已完成

- [x] 将本地构建目录集中到 `.build/`。
- [x] 将打包产物集中到 `.artifacts/`。
- [x] 将平台脚本、许可证说明和发布辅助文件归入 `packaging/`。
- [x] 将 Kirigami/ECM 等本地依赖放入 `.third_party/`。
- [x] 保留旧缓存迁移归档，避免直接删除用户已有构建数据。

### 阶段 C：Kirigami 接入 —— 桌面页面组件化已完成，移动端分发待评估

- [x] 接入 KDE Kirigami 6.8.0 和 Extra CMake Modules 6.8.0。
- [x] 增加 `MainKirigami.qml` 应用壳。
- [x] 检测到 Kirigami 时启用 Kirigami 壳层。
- [x] 未安装 Kirigami 时自动回退到 `Main.qml` 的 Qt Quick Controls 2 壳层。
- [x] 保证桌面侧栏、移动端底部导航和共享页面组件可以复用。
- [x] 新增桌面专用 `qml/kirigami/` 页面，实现 `ScrollablePage`、`Card`、`InlineMessage`、`ActionToolBar`、`PlaceholderMessage` 和 `FormLayout` 组件化。
- [x] 将 Kirigami 页面与共享 C++ 模型连接，保持下载、队列、工具检测和设置行为一致。
- [x] 在窄桌面宽度（`560–1059 px`）使用 Kirigami `NavigationTabBar` 替换单一抽屉入口；宽桌面继续使用 `GlobalDrawer`，Android 仍使用已验收的 Qt Quick Controls 2 底部导航。
- [ ] 为 Android 构建独立的 Kirigami 依赖分发方案；在此之前 Android 保持 Qt Quick Controls 2 回退壳层。

### 阶段 D：UI 设计与落地 —— 桌面浅色与移动深色双基线已完成

- [x] 建立“Signal Desk”视觉方向、颜色令牌、字体层级和状态语义。
- [x] 完成桌面工作台布局。
- [x] 完成窄屏/移动端单列布局基础。
- [x] 完成新建下载、下载队列和设置三类页面。
- [x] 完成下载进度、失败、重试、取消和打开文件等状态组件。
- [x] 将 UI 设计文档中的产品名称同步为 Video Downloader。
- [x] 按手机截图参考完成 Graphite Rose 首轮 QML 实现：深色默认主题、灰粉主动作、细描边面板、底部选中胶囊、分组工具列表和单色图标。
- [x] 根据 Windows 桌面反馈补充参考界面启发的浅色基线：`#F3F4F6` 画布、白色内容面、`#1677FF` 主动作、浅蓝选中态和更克制的桌面圆角。
- [x] 将 Windows 默认主题设为浅色、Android 默认主题保留为深色；用户手动选择的主题继续持久化。
- [x] 保留现有下载、解析、队列、存储和 Android 生命周期逻辑，只替换视觉令牌与布局表现。

设计细节见：[Video Downloader UI 设计方案](ReClipQt-UI设计.md)。

### 阶段 D.1：移动端截图风格对齐 —— Graphite Rose 已落地，桌面色彩另行收敛

- [x] 读取已连接 Android 真机在 2026-09-06 21:48 生成的三张截图，分别提炼仪表盘、配置和工具页的共同视觉语言。
- [x] 将参考风格整理为 Graphite Rose：近黑画布、灰粉主动作、低对比度选中胶囊、细描边、分组列表和绿色健康状态。
- [x] 明确桌面端只继承视觉语法，不复制手机底部导航；移动端保留 Video Downloader 的业务命名，不照搬参考应用的网络代理文案。
- [x] 将截图参考结论、颜色令牌、响应式规则和桌面/移动端延展写入 [`ReClipQt-UI设计.md`](ReClipQt-UI设计.md) 0.9 版。
- [x] 用户确认视觉方向后，已改造 `Theme.qml`、应用壳、底部导航、仪表盘/配置/工具列表和相关组件；本阶段没有改变下载业务逻辑。
- [x] 根据当前 UI 设计先完成桌面 Kirigami 页面组件化，保留共享业务控件以减少逻辑复制。
- [ ] 根据真机后续反馈继续校准图标、间距、列表密度和桌面 Kirigami 壳层，并补齐无障碍审查。
- [x] 记录当前 UI 库边界：桌面 Kirigami 已用于应用壳和页面结构，Android 仍使用 Qt Quick Controls 2 回退实现，以保证移动端构建不依赖本地桌面 Kirigami 插件。
- [x] 记录双主题边界：Windows 默认浅色工作台，Android 默认 Graphite Rose 深色界面；共享组件通过 `Theme.qml` 保持语义颜色一致。

### 阶段 D.2：参考界面收敛与字体优化 —— 已完成（2026-09-07）

- [x] 将 Windows 桌面主色从绿色收敛为 `#1677FF`，绿色只保留给工具就绪、媒体准备好和任务完成等健康状态。
- [x] 将桌面画布、侧栏、白色卡片、选中态、细边框和按钮圆角统一到参考界面的浅灰/白/蓝信息层级。
- [x] 将桌面侧栏收窄到约 196 px、右侧活动栏收敛到约 300 px，并统一主页面 24 px 留白和 16 px 区块间距。
- [x] 在 `Theme.qml` 中按平台选择 `Microsoft YaHei UI`、`PingFang SC`、`Noto Sans CJK SC` 和 `Cascadia Mono`/系统等宽字体，统一标题、正文和技术信息层级。
- [x] 同步调整 Qt Quick Controls 2 回退壳与 Kirigami 壳，避免安装 Kirigami 前后出现两套明显不同的桌面视觉。
- [x] Windows Kirigami Release 构建通过，CTest 保持 6/6，offscreen 启动检查未出现 QML 创建失败；设计令牌和落地项已同步到 [`ReClipQt-UI设计.md`](ReClipQt-UI设计.md)。

本轮截图仅保存在本机被忽略的 `.scratch/phone-ui-references/` 目录，不作为发布资源或 Git 提交内容。

### 阶段 E：文档和产品命名 —— 已完成

- [x] 将根目录 README 重写为完整的 English / 简体中文双语文档。
- [x] 补充功能、依赖、构建、测试、打包、目录结构和使用限制说明。
- [x] 英文文案采用自然的英国英语表达，例如 `organised` 和 `Licence`。
- [x] 将对外产品名统一为 **Video Downloader**。
- [x] 在 README 中明确说明仍保留的 `ReClip` 内部兼容标识。

文档入口：[README.md](README.md)。

### 阶段 F：测试、打包和 CI —— 基础验证已完成

- [x] Windows 配置、Release 编译通过。
- [x] Windows Kirigami 配置、Release 编译通过。
- [x] CTest 6/6 通过。
- [x] macOS 构建、应用包生成和验证通过。
- [x] Linux 构建、QML lint、AppImage 生成和 offscreen 启动检查通过。
- [x] Windows 便携包生成通过。
- [x] 修复 Linux QML 输出目录与可执行文件名冲突。
- [x] 修复 Clang/GCC 下 `QUrl` 初始化歧义。
- [x] 修复 AppImage 对未使用 Mimer SQL 插件的依赖扫描问题。
- [x] 为 AppImage 补充应用图标和 `Icon` 元数据。
- [x] 规范化 Linux Bash 打包脚本的 LF 换行。
- [x] Windows Kirigami 页面组件化 Release 构建通过，CTest 保持 6/6。
- [x] 复用 Android arm64-v8a full-runtime 构建目录完成回退构建，确认 `RECLIP_ENABLE_KIRIGAMI=OFF` 时不编译桌面 Kirigami 页面。

#### 窄桌面导航执行目标（2026-09-06）

- 在 `MainKirigami.qml` 中增加 Kirigami `NavigationTabBar`，只在非移动、非宽桌面窗口显示。
- 三个导航动作继续调用现有 `navigate()`，不复制页面状态或下载队列逻辑。
- 保持 `GlobalDrawer` 作为宽桌面主导航；窄桌面隐藏重复抽屉入口，避免同时出现两套一级导航。
- 验收要求：Windows Kirigami Release 构建通过、应用 offscreen 启动无 QML 错误，窄桌面导航分支通过 QML 编译和结构检查，Android 回退构建不包含 Kirigami 页面或导航组件。

#### Kirigami 组件化执行记录（2026-09-06）

- 桌面入口仍由 `MainKirigami.qml` 负责，颜色令牌继续来自共享的 `Theme.qml`，避免 Kirigami 默认主题覆盖 Windows 浅色或 Android Graphite Rose 视觉方向。
- `qml/kirigami/` 只在 `RECLIP_HAS_KIRIGAMI` 为真时加入 `qt_add_qml_module`；Android 构建脚本继续传入 `-DRECLIP_ENABLE_KIRIGAMI=OFF`。
- 新页面分别复用 `LinkCapture`、`MediaPreview`、`DownloadStatusPanel`、`DownloadRow` 和 `ToolStatusRow`，因此第三方 UI 替换没有复制下载业务逻辑。
- `MainKirigami.qml` 在 `560–1059 px` 的非移动窗口显示 `Kirigami.NavigationTabBar`，宽桌面保持 `GlobalDrawer`，并自动隐藏右侧活动栏以保留主内容宽度。
- `Theme.qml` 已增加平台感知的桌面浅色令牌、蓝色主动作和绿色健康状态；深色 Graphite Rose 仍作为 Android 默认与用户可选主题保留。
- Windows 验证目录为 `.build/windows-kirigami-ui`，Release 构建成功，CTest 为 6/6；offscreen 启动 8 秒未出现崩溃。
- Android 验证目录为 `.build/android-arm64-full-runtime`，回退构建成功，full FFmpegKit/yt-dlp 运行时配置保持不变。
- [x] 修复 Windows 包内 FFmpeg 误报缺失：`ToolLocator` 现在会优先检查发布目录 `bin/ffmpeg.exe`、`bin/yt-dlp.exe` 等带 `.exe` 的候选路径；已用重新生成的 portable 包和包内 `ReClipToolLocatorTest` 验证通过，FFmpeg/ffprobe 均可执行。
- [x] 2026-09-07 修复 Windows FFmpeg 版本探测异常退出：FFmpeg 使用兼容 Windows `QProcess` 的 `-version` 参数，检测/下载进程同时继承工具目录作为工作目录并置于 `PATH` 首位；Qt 工具定位测试和 6/6 桌面测试通过。修复版便携包位于 `.artifacts/windows/ReClip-Release-fixed2`。

最近一次完整 CI 验证记录：[GitHub Actions run 33961118472](https://github.com/zhaojiaxiang97-crypto/ReClipMac/actions/runs/33961118472)。

## 4. 下一阶段计划

### 优先级 P0：提交当前本地改动并重新跑 CI

- [ ] 检查当前工作区 diff，确认 README、命名、UI 文档和打包元数据没有遗漏。
- [ ] 将当前命名和文档改动提交到 `main`。
- [ ] 重新验证 Windows、macOS、Linux 三个平台的 CI。
- [ ] 确认 GitHub 分支页的 Checks 状态与最新提交一致。

### 优先级 P1：应用界面国际化

- [ ] 将 QML 中的中文界面字符串提取到 Qt 翻译资源。
- [ ] 增加简体中文和 English 两套界面翻译。
- [ ] 在设置中加入语言选择，并保留系统语言选项。
- [ ] 检查移动端窄屏布局下的英文文本长度和按钮溢出。

### 优先级 P1：Android 优先移植 —— 已开始实现

当前状态：**Android 构建基线、手机端应用壳、外部链接入口、前台下载和后台保护纵向切片已接入**。API 35 x86_64 模拟器与一台 Android 14 / API 34 / arm64-v8a 真机均已完成启动、导航、外部链接、Home/恢复和物理横屏的基础验收；解析、MP4、MP3、进度、取消、重试（含通知动作）、SAF 导出、系统分享面板、队列持久化、前台通知、网络失败收尾和进程强制停止后的任务恢复已经在受控测试媒体上完成验证。现阶段仍需完成正式运行时分发审查、锁屏/网络切换/低存储实机矩阵、正式签名和进程被系统回收后的自动恢复策略。

#### Android 移植原则

- 先完成 Android，再评估 iOS；不在同一阶段同时处理两个移动平台的差异。
- 下载核心逻辑继续放在 C++，平台差异通过平台服务接口隔离。
- 不把桌面端的 `PATH`、绝对文件路径、系统托盘和窗口行为带入 Android。
- 不直接假定 Android 可以像桌面一样通过 `QProcess` 启动现有 `yt-dlp` 和 FFmpeg；先做可行性验证。
- 第一阶段优先支持 arm64-v8a 真机和模拟器，确认稳定后再扩展其他 ABI。

#### Android 需要先解决的问题

| 问题 | 当前桌面方案 | Android 方案方向 |
| --- | --- | --- |
| 下载引擎 | 从 PATH 或用户配置路径查找 `yt-dlp`、FFmpeg | 评估随 APK/动态下载的 arm64 工具、嵌入式运行时或独立引擎；形成可维护的 `RuntimeToolProvider` |
| 文件目录 | 使用桌面目录和系统文件管理器 | 使用应用私有目录，并通过 Android 文件选择器/Storage Access Framework 让用户选择导出目录 |
| 进程生命周期 | 桌面进程可持续运行 | 设计前台服务或可恢复任务，处理锁屏、切后台、系统回收和取消 |
| 权限 | 桌面通常不需要运行时存储权限 | 只申请当前 Android 版本所需的最小权限，并区分网络、通知和用户选择目录权限 |
| URL 输入 | 剪贴板和拖拽 | 支持粘贴、`ACTION_SEND`/分享入口和 `ACTION_VIEW`，同时保留手动输入 |
| 文件操作 | 打开目录、系统托盘、桌面通知 | 改为打开文件、分享文件和 Android 通知；桌面专用能力移到平台适配层 |
| 发布 | `.app`、AppImage、Windows 便携包 | `androiddeployqt`/Gradle APK 或 AAB、签名、ABI、版本和权限清单 |

#### Android 实施阶段

**A0：工具链和最小 APK 可行性验证**

- [x] 安装并记录与当前 Qt 版本匹配的 Android SDK、NDK、JDK、Gradle 和 Qt Android Kit。
- [x] 增加 Android CMake 配置和 `androiddeployqt`/Gradle 入口，不影响现有桌面配置。
- [x] 生成 arm64-v8a Debug APK，并额外生成 x86_64 Debug APK 供后续模拟器尝试。
- [x] 在 API 35 x86_64 模拟器上安装并启动最新 x86_64 Debug APK。
- [x] 在 Xiaomi 24094RAD4C（Android 14 / API 34 / arm64-v8a）真机上安装、启动并完成基础运行验收。
- [x] 在模拟器上验证 Qt Quick Controls 2 QML 壳层启动、窄屏布局、旋转、切后台/恢复和显式 `VIEW`/`SEND` Intent。
- [x] 接入 Android 返回键的页面回退逻辑，并在真机验证“队列/设置 -> 新建下载”的系统返回行为。

#### A0 当前环境记录

| 项目 | 当前值 |
| --- | --- |
| Qt 主机 Kit | Qt 6.8.3 / `msvc2022_64` |
| Qt Android target Kit | Qt 6.8.3 / `android_arm64_v8a`；另有 `android_x86_64` |
| Android SDK | `C:\Android\sdk`，platform-tools 37.0.1 |
| Android platform / target | 构建工具链 API 34；应用 target SDK 35；本机同时安装 API 35/36 |
| Deploy compile SDK | 当前选择 API 36；AGP 8.6.0 会给出兼容性提示，但 APK 构建通过 |
| Android NDK | 26.1.10909125 |
| Build-tools | 35.0.0、36.0.0 |
| JDK | 17.0.12 |
| Gradle / Android Gradle Plugin | Gradle 8.10 / AGP 8.6.0 |
| CMake / Ninja | CMake 3.30.5 / Ninja 1.12.1 |
| Android Emulator Hypervisor Driver | AEHD 2.2，已安装并可用 |
| 已验证产物 | `.build/android-arm64-full-runtime/android-build/build/outputs/apk/debug/android-build-debug.apk`、`.build/android-x86_64-vulkan-detect/android-build/build/outputs/apk/debug/android-build-debug.apk` |
| APK 身份 | `com.reclip.videodownloader`，应用名 `Video Downloader`，最低 API 28，已验证 ABI `arm64-v8a` / `x86_64` |

构建入口为 [`scripts/android/Build-Android.ps1`](scripts/android/Build-Android.ps1)。当前主机已安装 AEHD 并可运行 x86_64 模拟器；已连接并验证一台支持的 arm64-v8a 真机，后续重点转为物理旋转、下载工具运行时和完整下载验收。

Android 构建脚本目前显式关闭 Kirigami，使用已经验证过的 Qt Quick
Controls 2 移动端回退壳层；Kirigami 的 Android 依赖和运行时打包会在后续
移动端 UI ticket 中单独评估，不把桌面 `.third_party` 目录直接塞进 APK。

**A1：平台能力抽象**

- [ ] 新增 `PlatformServices` 抽象，隔离文件选择、打开文件、分享文件、通知和返回行为。
- [ ] 将 `QDesktopServices`、桌面文件夹打开和系统托盘逻辑限制在桌面实现中。
- [x] 为 Android 实现文件选择器、打开目录、分享 Intent 和文件打开桥接；通知与生命周期回调继续由后续 ticket 处理。
- [x] 建立 `PlatformPaths` 与 `PlatformStorage`，让 Android 工作输出进入应用私有目录，缓存位置保持独立，用户导出目录使用 SAF 持久化 URI。
- [ ] 为旧设置路径和 Android 新路径准备迁移策略。

**A2：yt-dlp/FFmpeg 运行时可行性验证**

- [x] 完成 Android arm64-v8a FFmpeg 构建候选的真机 POC，并记录许可证与分发审查项；正式发布仍需完成来源复核和通知清单。
- [x] 选定 Android yt-dlp 的原型运行方式：嵌入 Python 的 `yt-dlp-android` AAR；当前已完成 Android 引擎桥接原型，正式分发仍需完成依赖和许可证审查。
- [x] 实现不依赖系统 PATH 的运行时工具定位、版本检查和错误提示；Android 优先检查应用私有 `files/bin`，并支持从 APK assets 解包可选工具。
- [x] 增加可选 `AndroidDownloadEngine` JNI bridge：Android AAR 可向 Qt 传递结构化媒体信息、下载进度、完成和取消结果；桌面端继续使用 `QProcess`。
- [x] 在 Android 真机上完成解析、MP4 下载、MP3 提取、进度解析、取消和重试的完整验收。
  - [x] 使用公开测试媒体 `https://assets.testfiles.dev/video/sample-3s.mp4` 验证结构化解析和 MP4 下载；文件已写入应用私有目录，大小为 122,786 bytes。
  - [x] 补齐 Android FFmpeg/MP3 提取链路、运行时依赖打包、源下载进度和转换阶段状态回调。
  - [x] 完成 Android 端取消和失败重试的真机验收：慢速受控流取消后回到“已取消/重试”，`.part/.ytdl` 临时文件清理，随后重试生成完整 MP4。
- [ ] 如果现有 `QProcess` 方案无法稳定工作，先抽象下载引擎接口，再实现 Android 专用后端。

**A3：移动端下载任务和存储**

- [x] Android 队列页已接入同一个 `AndroidDownloadEngine`：支持移动端“全部开始”、单任务顺序执行、进度/完成/失败回调和应用私有目录输出。
- [x] 使用 `QSettings` 持久化队列 JSON；重启后把 `downloading/exporting` 任务标记为“应用关闭时中断，可重试”，不自动偷偷发起网络请求。
- [x] 长任务采用同进程 Android `dataSync` 前台服务；短任务当前复用同一模型，后续再按耗电和系统限制细分。
- [x] 增加通知中的下载进度、成功/失败终态和取消入口，并申请 Android 13+ 的通知权限。
- [x] 增加通知中的重试动作，并完成通知按钮的完整交互验收。
- [x] 验证用户选择目录、应用私有目录和大文件写入，不依赖广泛存储权限。
- [x] 增加下载前存储卷检查（目录可用且至少保留 16 MiB），并统一网络断开、连接拒绝、DNS 失败和磁盘不足的可操作错误提示。
- [x] 真机验证网络中断：停止受控慢速 HTTP 服务后，任务进入失败并保留“重试”，不生成伪完成文件；重建 APK 后确认 `.part/.ytdl` 临时文件会被异步清理。
- [x] 真机验证进程强制停止恢复：下载约 29.7% 时 `force-stop`，重启后任务持久化为 `interrupted`，队列显示“应用关闭时中断，可重试”。
- [x] 真机验证屏幕关闭/锁屏过渡：`mWakefulness=Dozing` 时前台服务仍保持 `isForeground=true`，唤醒后任务链路未崩溃。
- [x] 真机验证撤销通知权限后的下载行为：在 Xiaomi Android 14 上将 `POST_NOTIFICATIONS` 设为 `granted=false`/`USER_FIXED`，从 QML 队列真实入口启动受控慢速下载，前台服务仍为 `isForeground=true`，任务完成并生成 4,956,176 bytes 文件，无 Java/runtime 崩溃；测试结束后已恢复权限并清理测试文件。
- [x] 真机验证重复启动：对队列“全部开始”连续点击两次，仍只保留一个活动任务和一个前台服务，最终只生成一个 4,956,176 bytes 输出文件。
- [x] 真机验证 Wi-Fi 切换：下载开发机局域网慢速媒体时关闭真机 Wi-Fi，任务可收敛为失败/可重试，错误显示为“网络连接中断，请检查网络后重试”，服务退出且不保留输出文件；测试结束后已恢复 Wi-Fi、队列和权限。
- [x] 真机验证受限下载卷预检：临时将下载目录指向 Android 不可用的 `/proc` 卷，任务在启动服务前进入“存储空间不足或下载位置不可用”，没有创建输出文件。
- [ ] 在不影响设备稳定性的前提下验证物理低剩余空间表现。

**A4：Android UI 和系统交互**

- [ ] 将桌面三栏工作台重组为手机页面栈和底部导航，而不是简单缩放桌面布局。
- [ ] 优化触摸目标、返回键、系统输入法、选择器、对话框和横竖屏切换。
- [x] 完善分享链接、从其他应用接收 URL、分享已下载文件和打开文件。
- [ ] 完成简体中文/English 界面翻译，并检查英文在窄屏上的换行和溢出。
- [ ] 完成 TalkBack、键盘、动态字体和高对比度的基础可访问性检查。

**A5：测试、CI 和发布**

- [ ] 增加 Android 构建 job，产出未签名 Debug APK 供测试。
- [ ] 在模拟器上运行 QML 启动、工具检测、队列和设置 smoke test。
- [ ] 在 arm64-v8a 真机上执行授权媒体 URL 的端到端下载测试。
- [ ] 配置正式签名、AAB/APK 产物、版本号、权限清单和发布说明。
- [ ] 在 Android 达到稳定发布基线后，再单独规划 iOS 移植。

#### Android 本轮执行记录（2026-09-06）

本轮已完成 Android 的第一条可构建、可扩展纵向切片：

- 已安装并记录 Qt 6.8.3 Android Kit、Android SDK、NDK 26.1.10909125、JDK 17.0.12、Gradle 8.10、AGP 8.6.0、CMake 3.30.5 和 Ninja 1.12.1。
- 已增加 [`scripts/android/Build-Android.ps1`](scripts/android/Build-Android.ps1)，构建产物统一放入 `.build/`，不改变桌面端构建入口。
- 已增加 Android Manifest、应用资源和 `MainActivity`，包名为 `com.reclip.videodownloader`，用户可见名称为 `Video Downloader`，最低 API 28，target SDK 35。
- 已接入 `ACTION_SEND` 文本分享、HTTP(S) `ACTION_VIEW` 链接和 C++/Java URL 桥接；重复分享同一个链接也会触发新的解析。
- Qt Quick Controls 2 移动端壳层已在 Android 上强制使用窄屏布局；桌面壳层仍保持原有导航方式。Android 返回键会优先返回新建下载页，再允许退出应用。
- 已增加 `PlatformPaths`，Android 默认下载输出进入应用私有目录；桌面系统仍使用原有 Downloads/ReClip 路径。
- 已增加 `PlatformStorage` 及 Android SAF/FileProvider 桥接：工作文件先写入应用私有目录，用户可选择导出目录，导出目录 URI 和显示名称会持久化。
- 真机已验收导出目录选择、权限确认、设置页状态回显、强制停止后重新启动的状态恢复，以及“打开导出目录”重新进入已选目录；首次选择器会优先进入 `Download` 子目录，避免 Android 根目录不可授权的提示。
- 已增加 Android 运行时目录约定：优先检查应用私有 `files/bin`，`MainActivity` 可在首次启动时把 `android/assets/bin` 中的可选工具解包并设为可执行；当前仓库不擅自携带 yt-dlp/FFmpeg 二进制。
- 已固定并验证一个 Android arm64-v8a 的 FFmpeg 9.0 POC：来源为 `hzw1199/Android-FFmpeg-Prebuilt` commit `90231cc0105aef4f76926b911535f5eb73511b86`，SHA-256 为 `9085507B0DC32643B4D6D084A7E7D3469EF17907A7BA15C22D3997ED09C932AA`；真机已通过版本检查、合成 MP4 和再次读取验证，尚未打入 APK。
- 已增加 `scripts/android/Fetch-AndroidFfmpeg.ps1`，用于按固定 commit 下载并校验该 POC 运行时；生成文件只进入被忽略的 `.artifacts/` 目录。
- 已增加 `scripts/android/Fetch-AndroidYtDlp.ps1`，固定 Maven Central 的 `yt-dlp-android:2.0.2` 和 SHA-256；AAR 仅进入被忽略的 `.artifacts/` 目录。
- `scripts/android/Build-Android.ps1` 新增 `-WithYtDlpAndroid` 可选开关：构建时把已校验 AAR 暂存到 `.build/.../android-package/libs`，不把大二进制提交到仓库；普通 Android 构建路径保持可用。
- 已增加 `scripts/android/Fetch-AndroidFfmpegKit.ps1`，改为固定 GitHub 仓库 `ffmpegkit-maintained/ffmpeg` 的 `v8.1.7-lts-android` release asset：`ffmpeg-kit-full-8.1.7-arm64-v8a-x86_64.aar`，SHA-256 为 `C3CBC81D498175FD2AA69EE2DFE7DAFBF519052A96283C2568FE5B3B16618456`；同时保留 `smart-exception-common/java:0.2.1` 校验依赖，它们只作为可选 Android 构建输入，不提交到 Git。
- `AndroidYtDlpBridge` 已通过可选 FFmpegKit Java API 完成音频源下载后的 MP3 转换；缺少 FFmpegKit 时仍保持明确失败回调，不影响普通 Android 壳层构建。
- 已修复 `ToolLocator` 的 Android 误报：FFmpegKit 是嵌入 APK 的 Java/native AAR，不能按桌面 `ffmpeg` 可执行文件或 PATH 检测；现在通过 `com.arthenica.ffmpegkit.FFmpegKit` 类探测，并显示 `FFmpegKit 8.1.7` 与“Android 内置 FFmpegKit 运行时已就绪”。
- AAR 版 arm64-v8a Debug APK 已在 Xiaomi 24094RAD4C（Android 14 / API 34）真机安装；`MainActivity` 日志确认 Chaquopy/CPython 与 yt-dlp Android runtime 初始化成功。
- 已新增 [`src/AndroidDownloadEngine.{h,cpp}`](src/AndroidDownloadEngine.h) 和可选 [`AndroidYtDlpBridge.java`](android/optional-src/com/reclip/videodownloader/AndroidYtDlpBridge.java)：Android 媒体解析走嵌入 Python 的结构化 JSON，单任务下载走 yt-dlp Android Java API，桌面路径不改变。
- 真机已通过外部 `VIEW` Intent 发送 `https://example.com` 的失败回调验收：yt-dlp 返回“链接格式不受支持”，错误能回到 QML，未出现崩溃；公开测试媒体的成功解析和 MP4 下载已另外完成。
- 已使用公开测试媒体 `https://assets.testfiles.dev/video/sample-3s.mp4` 完成真机成功链路：解析结果显示 `sample-3s`，点击“下载 MP4”后生成 `files/downloads/VideoDownloader-sample-3s.mp4`，文件大小为 122,786 bytes，应用进程保持运行。
- 已将 `DownloadQueue` 接入 Android bridge，并为移动端显示“全部开始”入口；真机已验证加入队列、顺序启动、重复输出文件复用、队列完成状态和“已保存”状态回显。
- 已使用 GitHub release 的 `ffmpeg-kit-full:8.1.7` 和两个 `smart-exception` 运行时依赖重新构建并安装 Android Debug APK；full 包覆盖视频合并与音频提取所需的 FFmpeg 能力，真机冷启动无依赖缺失异常。
- 本次重新构建产物为 `.build/android-arm64-full-runtime/android-build/build/outputs/apk/debug/android-build-debug.apk`；APK 内已确认存在 `libffmpegkit.so`、`libavcodec.so`、`libavformat.so` 等 arm64 native library，设置页已显示 `FFmpegKit 8.1.7` 与“Android 内置 FFmpegKit 运行时已就绪”。
- 已通过 `adb reverse` 让真机访问本地 3 秒 AAC + MPEG-4 测试媒体：源 MP4 为 45,814 bytes，Android 私有目录生成 MP3 为 15,489 bytes，FFmpeg 日志返回 `success=true`；公网无音频样本也能正确返回“没有可转换音频流”的失败状态。
- 已在 Xiaomi 24094RAD4C（Android 14 / API 34 / arm64-v8a）上使用本地慢速受控 MP4 流验收取消和重试：下载进行到 1.3% 时点击“取消”，UI 进入“已取消”，下载目录没有残留 `.part/.ytdl`；点击“重试”后 UI 进入“下载完成”，生成 4,956,176 bytes 的完整 MP4。为保证窄屏可操作性，同时修复了速度/ETA 文本挤压取消按钮导致其宽度为 0 的布局问题。
- 已修复 Android SAF 导出桥接的 JNI 方法签名：`PlatformStorage` 现在按 Java `MainActivity.exportFile` 的五个字符串参数正确调用；真机重新下载后，私有目录和所选 `1_新建文件夹` 中均生成 4,956,176 bytes 的 MP4，分享按钮也成功打开系统 `MiuiChooserActivity`。
- 已为 `DownloadQueue` 增加跨进程重启可恢复的 JSON 持久化：每次队列变化保存任务 URL、格式、进度、输出路径、导出 URI 和错误信息；重新创建对象时将旧的活动任务归档为 `interrupted`，并在桌面单元测试中覆盖队列恢复和中断任务可重试。
- 已增加 `android/src/com/reclip/videodownloader/DownloadForegroundService.java`：下载时启动 `dataSync` 前台服务，使用 `downloads` 通知频道显示进度和“取消”操作；终态通知使用独立通知 ID 保留成功/失败结果。Manifest 已加入前台服务、data sync 和 Android 13+ 通知权限。
- 在 Xiaomi 24094RAD4C（Android 14 / API 34）上启动受控慢速下载后切到 Home，`dumpsys activity services` 确认 `DownloadForegroundService` 保持 `isForeground=true`、`foregroundId=4101`；通知包含进度和取消操作。完成后服务退出，终态“下载完成”通知仍可在系统通知记录中看到，输出文件为 4,956,176 bytes。
- 失败/取消终态通知现在携带“重试”动作：动作只把持久化队列任务 ID 交回 Qt/QML，由 `DownloadQueue::retryTask()` 统一重置任务并启动下载，不在 Java 层绕过队列重复发起请求。真机使用本地连接拒绝场景验证：通知记录包含 `重试` action，通过同等 Intent 触发后再次出现 `isForeground=true` 的下载服务，并生成新的失败终态通知。
- 已补齐异常下载收尾：桌面和 Android 均在启动前检查下载卷是否可用且至少保留 16 MiB；`connection refused`、`remote end closed`、DNS 失败、网络不可达和 `no space left on device` 等错误会归一为可操作的中文提示。Android yt-dlp 失败后会异步清理本次产生的 `.part/.ytdl` 文件。
- 在 Xiaomi 24094RAD4C（Android 14 / API 34 / arm64-v8a）上用重建 APK 验证网络中断：前台服务处于 `isForeground=true` 时停止本地慢速 HTTP 服务，任务显示“下载失败”和“网络连接中断，请检查网络后重试”，保留“重试”，下载目录无临时文件残留。
- 同一真机验证进程恢复：下载约 29.7% 时执行 `am force-stop`，服务退出；重新启动并进入队列后，UI 显示“应用关闭时中断，可重试”，`QSettings` 中任务状态为 `interrupted`，没有自动发起网络请求。
- 同一真机验证屏幕关闭期间的后台保护：下载服务保持 `isForeground=true`，设备进入 `mWakefulness=Dozing`，唤醒后未出现应用崩溃。
- 本轮异常收尾代码加入后，Windows Release 目标重新编译通过，CTest 为 **6/6**；Android arm64-v8a AAR Debug APK 重新构建并覆盖安装成功。
- 本轮一次冷启动截图曾出现 QML 场景图颜色撕裂，但 UIAutomator 仍能读取完整控件树，`logcat` 未发现 Java/native 崩溃；后续渲染日志已将其升级为 Android Qt Quick 图形合成兼容性问题处理，不将其误判为下载业务成功。
- 已在 Xiaomi 24094RAD4C（Android 14 / API 34 / arm64-v8a）真机上撤销 `POST_NOTIFICATIONS` 后通过真实 QML 队列入口启动受控慢速下载：权限状态为 `granted=false`/`USER_FIXED` 时，`DownloadForegroundService` 仍进入 `isForeground=true`，任务完成并生成 4,956,176 bytes MP4，服务正常退出且 `logcat` 无 Java/runtime 崩溃；测试结束后恢复通知权限并清理测试产物。
- 已在同一真机上对队列“全部开始”连续点击两次进行重复启动验收：活动队列任务和 `DownloadForegroundService` 均保持单实例，最终只生成一个 4,956,176 bytes MP4，测试结束后已清理输出并恢复原队列。
- 已在同一真机上关闭 Wi-Fi 验证网络切换失败收尾：任务从 `downloading` 进入失败态，Android `Errno 103 / Software caused connection abort` 已归一为“网络连接中断，请检查网络后重试”，前台服务退出且没有输出文件；已补充桌面和 Android 两处错误映射并重建安装 APK。
- 已在同一真机上验证受限下载卷预检：临时把下载目录设置为 `/proc`，队列未启动 `DownloadForegroundService`，直接持久化为“存储空间不足”，没有产生下载文件；原配置已恢复。真实填满设备空间仍未执行，以避免影响真机稳定性。
- 已在 Xiaomi 24094RAD4C（Android 14 / API 34 / arm64-v8a）真机上覆盖安装最新 Debug APK；设备上的小米安全中心最初拦截了 ADB 安装，改为用户确认安装后已恢复正常，后续 ADB 覆盖安装返回 `Success`。
- 真机已验证冷启动、底部导航进入队列、系统返回回到新建下载页、显式 `ACTION_VIEW`/`ACTION_SEND` 入口，以及 Home/恢复后的进程存活；测试期间未发现应用崩溃签名。
- 真机 UIAutomator 层级已确认手机单列布局、底部三项导航、媒体链接输入框和解析/剪贴板按钮均已渲染。
- 针对部分 Qt/Android 组合把系统返回动作作为窗口关闭请求的问题，已在普通 Qt Quick 壳和 Kirigami 壳补充 `onClosing` 拦截，避免页面返回直接退出应用。

### Android 图形渲染兼容性诊断 —— 进行中

- [x] 在 Xiaomi 24094RAD4C（Android 14 / API 34 / arm64-v8a）上稳定复现冷启动后的四色象限、斜线和黑屏/空白渲染异常；Activity、QML 控件树和应用进程均保持正常。
- [x] 源码检查确认异常颜色不是 QML 主题声明，也没有 `ShaderEffect`、`Canvas` 或自定义 OpenGL 绘制；Android 构建当前明确关闭 Kirigami（`RECLIP_ENABLE_KIRIGAMI=OFF`）。
- [x] 临时开启 Qt 场景图日志确认：使用 threaded render loop，Qt Quick 通过 QRhi 选择 OpenGL，设备驱动报告为 Imagination Technologies PowerVR B-Series BXM-8-256 / OpenGL ES 3.2。
- [x] 记录到同一启动窗口的渲染错误：`OpenGLRenderer: Unable to match the desired swap behavior`、`GrallocUnregisterBuffer: Cannot free a locked buffer` 和 `Gralloc4: freeBuffer failed with 2`；初步归因于 Qt 6.8.3 OpenGL RHI 与设备 IMGSRV/Gralloc/BufferQueue 合成链路的兼容性。
- [x] 临时强制 Software 渲染进行差分测试：四色撕裂消失但内容区变为空白，日志出现 `QRhiGles2: Failed to create context`；因此暂不将 Software 作为全 Android 默认方案。
- [x] 临时设置 `QSG_RENDER_LOOP=basic` 进行差分测试：真机仍出现四色撕裂和 `IMGSRV/Gralloc` 错误，排除仅由 threaded render loop 引起的可能。
- [x] 在确认真机具备 Vulkan feature 后临时设置 `QSG_RHI_BACKEND=vulkan`：首页和下载队列恢复正常，底部导航可交互，UIAutomator 能读取完整 QML 控件树，冷启动截图未再出现四色撕裂。
- [x] 将 Android 默认渲染策略整理为“检测到 Vulkan 时优先 Vulkan”，并允许启动时通过已有 `QSG_RHI_BACKEND` 环境变量覆盖；Software 不作为默认后端。
- [x] 通过 `QNativeInterface::QAndroidApplication` 查询 `android.hardware.vulkan.level/version`；没有 Vulkan feature 时不强制后端，让 Qt 使用默认回退路径。
- [x] 构建并安装能力探测版 APK：`.build/android-arm64-vulkan-detect/android-build/build/outputs/apk/debug/android-build-debug.apk`；当前真机冷启动、首页控件、底部导航和下载队列页面均通过验证。
- [x] 使用同一能力探测代码成功构建 x86_64 Debug APK：`.build/android-x86_64-vulkan-detect/android-build/build/outputs/apk/debug/android-build-debug.apk`。
- [x] 创建并启动 API 35 `google_apis` x86_64 AVD（`ReClipQtApi35`）；AEHD 加速可用，安装能力探测版 APK 后完成通知权限确认、冷启动和 QML 控件树验收。模拟器画面正常，无四色撕裂、黑屏或 Qt Quick 致命渲染错误；本次 x86_64 渲染验证未打包 yt-dlp/FFmpeg AAR，因此页面显示“下载工具还没有准备好”属于预期结果。
- [x] Vulkan 默认策略加入后，Windows Release 重新编译通过，CTest 保持 **6/6**。
- [ ] 在真正不支持 Vulkan 的 Android 设备上实测 Qt 默认 OpenGL 回退策略，避免低端/旧设备兼容性回归；当前 API 35 x86_64 AVD 的 Android feature 列表仍声明 Vulkan（即使宿主机使用 SwiftShader），因此它不能替代无 Vulkan 设备。
- [ ] 根据设备矩阵决定是否增加 Vulkan 能力探测、兼容模式设置或 Qt 维护版本升级，并完成渲染回归验收。

验证结果：

- arm64-v8a 完整运行时 Debug APK 构建成功：`.build/android-arm64-full-runtime/android-build/build/outputs/apk/debug/android-build-debug.apk`。
- x86_64 Vulkan 能力探测 Debug APK 构建成功并安装到 API 35 x86_64 模拟器：`.build/android-x86_64-vulkan-detect/android-build/build/outputs/apk/debug/android-build-debug.apk`。
- APK 元数据已验证：包名、版本号 `1`、版本名 `0.1`、应用名、最低 API、target SDK 和 arm64-v8a ABI 均正确。
- x86_64 Debug APK 已安装并在 API 35 x86_64 模拟器上冷启动成功；能力探测逻辑、通知权限后的正常页面、底部导航区域和工具缺失提示均已确认。
- arm64-v8a Debug APK 已在 Android 14 / API 34 真机上冷启动成功；真机底部导航、系统返回、`VIEW`/`SEND` Intent、后台/恢复和物理横屏均通过基础验收。
- Windows Release 构建成功，CTest 保持 **6/6**。
- 在加入 `AndroidDownloadEngine` 桌面兼容实现后再次完成 Windows Release 增量构建，CTest 仍为 **6/6**，确认 Android 专用 JNI 代码不会破坏桌面测试目标。
- 构建过程中出现的 QML import scanner 提示和 AGP 对 compileSdk 36 的兼容性提示均未导致构建失败，需在后续依赖整理时再清理。
- [x] 2026-09-06 清理历史构建缓存：`.build/` 下 34 个旧构建目录（约 17.52 GB）已移入 Windows 回收站；保留 `windows-kirigami-ui`、`android-arm64-full-runtime`、`android-arm64-vulkan-detect` 和 `android-x86_64-vulkan-detect` 四个当前验证目录。`.artifacts/`、`.third_party/` 和源码未改动。

当前未完成项和外部条件：

- Android Emulator Hypervisor Driver 已安装，`emulator -accel-check` 已确认 AEHD 2.2 可用；API 35 x86_64 模拟器已成功启动。
- 真机已通过物理横屏验收：系统方向为 landscape，QML 层级报告 `rotation="1"`，页面和 `MainActivity` 进程保持运行。
- Android 上的 yt-dlp/FFmpeg 正式分发审查、物理低存储实机窗口、进程被系统回收后的自动续作和正式签名仍未完成；通知权限撤销、重复启动、Wi-Fi 切换和不可用下载卷预检已经在真机验证通过。当前已完成可选 FFmpegKit 音频 AAR 及其依赖打包、Android MP3 转换、取消/重试（含通知动作）、网络失败收尾、锁屏期间前台服务保持、SAF 导出/分享、队列持久化和前台通知真机验收，以及 Android 解析/单任务和队列 MP4 下载 bridge 的基础链路。

下一步先寻找或准备真正无 Vulkan 的 Android 验证环境，确认能力探测失败时的 Qt 默认回退；随后按 ticket 顺序处理物理低存储异常矩阵，再进入 Android 双语界面、可访问性、CI/AAB 和正式签名审查。

#### Android ticket 索引

Android 移植已拆成以下可独立验收的纵向 tickets，编号顺序同时表示依赖顺序：

1. [Android 构建基线](docs/tickets/android/01-android-build-baseline.md)
2. [Android 移动应用壳与链接入口](docs/tickets/android/02-android-app-shell-and-url-intake.md)
3. [Android 存储与导出目录](docs/tickets/android/03-android-storage-and-export.md)
4. [yt-dlp/FFmpeg Android 运行时验证](docs/tickets/android/04-android-runtime-tools.md)
5. [Android 首个完整下载流程](docs/tickets/android/05-android-foreground-download.md)
6. [后台下载与任务恢复](docs/tickets/android/06-android-background-and-recovery.md)
7. [Android 双语界面与可访问性](docs/tickets/android/07-android-localisation-and-accessibility.md)
8. [Android CI 与 APK/AAB 打包](docs/tickets/android/08-android-ci-and-packaging.md)
9. [Android 真机验收与桌面回归](docs/tickets/android/09-android-device-acceptance.md)

#### Android 第一阶段验收标准

1. 可以从 Qt 工程稳定生成 arm64-v8a Debug APK，并在模拟器和真机启动。
2. 手机竖屏页面可以完成：粘贴链接、解析媒体、选择格式、加入队列和查看状态。
3. 下载引擎不依赖系统 PATH，可以明确报告工具缺失、版本错误和权限问题。
4. 下载任务在切后台和锁屏后有明确行为；完成、失败和取消状态可恢复或可解释。
5. 用户可以选择导出目录，并在 Android 文件管理器或分享面板中使用结果文件。
6. 桌面端 Windows/macOS/Linux 的构建和测试不因 Android 适配而回归。

#### Android 阶段暂不处理

- iOS 原生权限、后台任务和签名发布。
- 多 ABI 全覆盖和低版本 Android 兼容。
- Android 应用商店自动发布。
- 在工具运行时和许可证方案未确认前承诺正式移动端发布。

### 优先级 P2：完整品牌迁移

- [ ] 决定是否将 QML URI 从 `ReClip` 改为新的模块名。
- [ ] 决定是否将可执行文件和各平台产物从 `ReClip` 改为 `VideoDownloader`。
- [ ] 设计旧版本设置、默认下载目录和安装目录的迁移策略。
- [ ] 如需改名 GitHub 仓库，再同步更新远程地址、README 链接和发布文档。

### 优先级 P2：发布质量

- [ ] 增加真实用户授权媒体 URL 的端到端下载测试。
- [ ] 在无 Qt 开发环境的干净机器上验证三平台产物。
- [ ] 完善 FFmpeg、yt-dlp、Qt、Kirigami 的版本记录和许可证清单。
- [ ] 配置正式版本号、变更日志和发布产物命名规则。

## 5. 完成标准

本次 Qt/QML 改造可以视为第一阶段完成，当满足以下条件：

1. README 的 English 和简体中文内容保持同步，普通用户可以独立完成安装、构建和使用。
2. Video Downloader 作为用户可见产品名在应用、文档和打包元数据中保持一致。
3. Windows、macOS 和 Linux 的构建与测试均通过，CTest 保持 6/6。
4. Linux AppImage、Windows 便携包和 macOS 应用包可以从 CI 产出。
5. Kirigami 可用时启用自适应壳层，不可用时仍能使用 Qt Quick Controls 2 回退界面。
6. 当前阶段只要求保留移动端 QML 布局基础；Android 支持不计入本次桌面阶段完成标准，必须另外满足上面的 Android 第一阶段验收标准。

## 6. 当前注意事项

- 当前本地工作区仍可能包含之前的构建迁移和 CI 修复改动，提交前应一起检查，避免误删已有用户修改。
- `ReClip` 内部标识暂时保留是有意的兼容策略，不代表用户看到的产品名仍然是 ReClip。
- 下载功能只应处理用户拥有保存权限的内容；项目不绕过 DRM、付费墙、身份验证或平台访问限制。
