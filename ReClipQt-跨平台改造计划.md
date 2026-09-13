# Video Downloader / ReClipQt 跨平台改造计划

> 更新时间：2026-09-13
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
- [x] 保证桌面侧栏、移动端顶部菜单/设置抽屉和共享页面组件可以复用。
- [x] 新增桌面专用 `qml/kirigami/` 页面，实现 `ScrollablePage`、`Card`、`InlineMessage`、`ActionToolBar`、`PlaceholderMessage` 和 `FormLayout` 组件化。
- [x] 将 Kirigami 页面与共享 C++ 模型连接，保持下载、队列、工具检测和设置行为一致。
- [x] 在窄桌面和移动端使用顶部左侧菜单按钮打开设置抽屉；宽桌面继续使用侧栏，移动端不再显示底部切换栏。
- [ ] 为 Android 构建独立的 Kirigami 依赖分发方案；在此之前 Android 保持 Qt Quick Controls 2 回退壳层。

### 阶段 D：UI 设计与落地 —— 桌面浅色与移动深色双基线已完成

- [x] 建立“Signal Desk”视觉方向、颜色令牌、字体层级和状态语义。
- [x] 完成桌面工作台布局。
- [x] 完成窄屏/移动端单列布局基础。
- [x] 完成新建下载、下载队列和设置三类页面。
- [x] 完成下载进度、失败、重试、取消和打开文件等状态组件。
- [x] 将 UI 设计文档中的产品名称同步为 Video Downloader。
- [x] 按手机截图参考完成 Graphite Rose 首轮 QML 实现：深色默认主题、灰粉主动作、细描边面板、顶部圆形菜单按钮、分组工具列表和单色图标。
- [x] 根据 Windows 桌面反馈补充参考界面启发的浅色基线：`#F3F4F6` 画布、白色内容面、`#1677FF` 主动作、浅蓝选中态和更克制的桌面圆角。
- [x] 将 Windows 默认主题设为浅色、Android 默认主题保留为深色；用户手动选择的主题继续持久化。
- [x] 保留现有下载、解析、队列、存储和 Android 生命周期逻辑，只替换视觉令牌与布局表现。

设计细节见：[Video Downloader UI 设计方案](ReClipQt-UI设计.md)。

### 阶段 D.1：移动端截图风格对齐 —— Graphite Rose 已落地，桌面色彩另行收敛

- [x] 读取已连接 Android 真机在 2026-09-06 21:48 生成的三张截图，分别提炼仪表盘、配置和工具页的共同视觉语言。
- [x] 将参考风格整理为 Graphite Rose：近黑画布、灰粉主动作、低对比度选中胶囊、细描边、分组列表和绿色健康状态。
- [x] 明确桌面端只继承视觉语法，不复制手机底部导航；移动端保留 Video Downloader 的业务命名，不照搬参考应用的网络代理文案。
- [x] 将截图参考结论、颜色令牌、响应式规则和桌面/移动端延展写入 [`ReClipQt-UI设计.md`](ReClipQt-UI设计.md) 0.9 版。
- [x] 用户确认视觉方向后，已改造 `Theme.qml`、应用壳、顶部菜单/设置抽屉、仪表盘/配置/工具列表和相关组件；本阶段没有改变下载业务逻辑。
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

### 阶段 D.3：设置页视觉收敛 —— 已完成（2026-09-12）

目标：让设置页继承当前桌面浅色工作台，而不是保留一套高对比的旧式工具面板。

- [x] 移除设置页的工具诊断区域、外部工具版本/路径编辑和手动重新检测入口；SDK 运行时由程序初始化，不再把 FFmpeg/FFprobe 当作用户可配置命令。
- [x] 下载页仅在运行时未就绪时保留一条简短状态提示，错误操作统一为“重新解析”；侧栏和顶栏使用“下载引擎”语义，不再引导用户进入工具诊断。
- [x] 明确下载目录反馈：目录不存在时说明会创建，选择目录后提供明确的保存/应用动作和状态标签；桌面端后续已将该配置卡片移入下载工作台。
- [x] 设置页不再承担桌面右侧传输队列布局；桌面设置页面已从运行页面栈移除，移动端抽屉只保留系统保存位置操作。

验收标准：

- 桌面工作台中的保存位置卡片与新建下载页保持同一浅色层级、圆角和按钮语言。
- 长路径不会挤压核心状态；用户可查看或复制完整值。
- 无下载任务时，保存位置卡片不会改变链接输入和媒体预览的主层级。

### 阶段 D.4：近期界面问题修复计划 —— 已实施并验收（2026-09-13）

目标：根据 Android 真机和近期功能截图，修复解析状态图标、加载提示布局、格式选择弹窗和下载队列标题显示问题，并保持 Windows 桌面端与 Android 端的视觉和行为一致。

本节记录的问题已完成代码修复和跨平台回归。近期截图证据保存在被忽略的 `.scratch/android-ui/functional/` 目录中，不作为发布资源。

#### D.4.1 解析状态图标

- [x] 检查 `qml/components/LinkCapture.qml` 中 `scan` 与 `loading` 的状态切换，确认“正在解析”图标的几何形状、旋转中心、裁切和动画方向。
- [x] 检查 `qml/components/IconGlyph.qml` 的 SVG path 与 896/1024 viewBox 缩放关系；确认原单段弧形填充在小尺寸下会产生弯月状误读。
- [x] 修正 `qml/components/AppButton.qml` 的禁用主按钮颜色：忙碌状态仍保证图标和“正在解析”文字具有足够对比度。
- [x] 将 loading 图标替换为 Qt `PathAngleArc` 绘制的环形分段旋转图标，并保持不依赖外部字体、网络资源或平台图标。

验收标准：解析期间图标位于按钮内容中心、顺时针连续旋转且不被裁切；按钮文字保持清晰；解析结束后恢复为静态的解析图标。

#### D.4.2 “正在读取媒体信息”与加载条重叠

原代码同时存在两套解析反馈：`LinkCapture` 卡片底部的忙碌细线，以及 `NewDownloadPage.qml` / `KirigamiNewDownloadPage.qml` 中的 `SignalTrace` 加文字状态行。两套指示器增加了布局重叠和信息重复的风险。

- [x] 统一解析反馈的显示位置和职责，移除输入卡片底部重复的忙碌细线。
- [x] 为状态文字和进度条分配独立的 `ColumnLayout` 空间，状态行固定保留 8 px 进度轨道并关闭重复 marker。
- [x] 同步修复 Qt Quick Controls 2 回退页面和 Kirigami 页面，两个壳层均使用相同布局。

验收标准：Android 窄屏、Windows 窄窗口和宽桌面下，“正在读取媒体信息”始终完整可见，加载条不穿过文字、不覆盖文字，也不会造成页面跳动。

#### D.4.3 解析媒体按钮的二维码/扫描图标

近期截图中的 `scan` 图标呈现为方向不明确的扫描框碎片。代码中该图标实际是静态扫描框 path，并没有受到 loading 旋转动画影响；因此需要优先修正图标资源和语义，而不是给它增加或删除旋转。

- [x] 明确产品语义为“扫描取景框”，而不是可旋转的二维码图案。
- [x] 保留四角扫描框 path，并将 `IconGlyph` 的填充规则改为 `WindingFill`，避免 Qt 渲染器把重叠角落拆成倒置碎片。
- [x] 在禁用、默认、解析中和解析成功后的按钮状态下检查图标可读性；解析中使用独立 loading 图标，成功后恢复静态扫描框。

验收标准：图标上下方向正确，四个角的开口方向一致，视觉上不会被误认为倒置或损坏的二维码；Android 与 Windows 显示比例一致。

#### D.4.4 格式和画质 ComboBox 主题化

问题表现为 `qml/components/MediaPreview.qml` 直接使用 Qt Quick Controls 2 的原生 `ComboBox`；由于 `src/main.cpp` 全局设置了 `Basic` 样式，弹出菜单出现白色选中项、黑色未选中项和突兀的方形边框。修复后媒体预览统一使用主题化的 `qml/components/AppSelect.qml`。

- [x] 以问题截图为参考，通过 ImageGen 生成 Graphite Rose 主题的下拉框设计参考图，保存于 `.scratch/android-ui/design/combo-popup-reference.png`，仅作为实现参考。
- [x] 以共享 `AppSelect` 为基础实现主题化弹窗：圆角表面、主题边框、明确选中态、统一文字颜色和足够大的触摸行高；弹层额外留出横向空间以避免 Android 高密度屏文字被截断。
- [x] Android 端验证弹窗在当前窄屏媒体预览区域可见；Windows 端沿用 Qt Controls 的键盘/鼠标交互，并保留 Escape 和点击外部关闭。
- [x] 格式选择和画质选择使用同一套组件，分别支持短文案、长画质列表、滚动和禁用状态。
- [x] 移除原生白色菜单的默认背景、边框和选中颜色，不引入平台特有的第二套视觉。

验收标准：MP4/MP3 格式菜单和画质菜单在 Android、Windows 两端均与周围卡片融为一体；选中项、悬停项、禁用项、长列表和靠近屏幕边缘的情况都不会出现白边、裁切或内容溢出。

#### D.4.5 下载队列显示媒体标题

`MediaInspector` 已从 yt-dlp 结果中读取 `title`，`DownloadRow` 也已经优先显示 `task.title`。问题发生在任务创建阶段：原来的 `DownloadQueue::addTask()` 只接收 URL、格式 ID 和格式，并将 `host + path` 写入 `task.title`；两个下载工作台页面也没有把 `inspector.title` 传入队列。

- [x] 增加兼容旧调用的 `DownloadQueue::addTaskWithTitle()` 接口，并由原三参数 `addTask()` 转发到新实现。
- [x] 在 `NewDownloadPage.qml` 和 `KirigamiNewDownloadPage.qml` 的加入队列路径中传递 `inspector.title`。
- [x] 标题为空时使用 `host + path` 的简短可读保底，不在普通队列标题区域显示完整 HTTPS 地址。
- [x] 保留标题的 JSON 持久化；当旧任务仍使用 URL fallback 标题时，同 URL 获得元数据后允许更新为真实标题。
- [x] 在 `ReClipDownloadQueueTest` 中覆盖标题更新、重复 URL 和重启后的标题恢复。

验收标准：解析一个有标题的媒体并加入队列后，队列项显示视频标题而不是 HTTPS 地址；应用重启后标题仍保留；无法取得标题时才显示简短且可读的保底名称。

#### D.4.6 实施顺序与跨平台回归

1. 修复 `IconGlyph`/`AppButton` 的 loading 与 scan 图标问题。
2. 统一解析状态反馈并消除加载条与文字的重叠。
3. 生成并确认 ComboBox 设计参考，再落地共享 `AppSelect` 弹窗。
4. 将媒体标题接入下载队列并处理旧任务兼容。
5. 完成 Windows Kirigami Release 编译、CTest、offscreen 启动检查，以及 Android arm64 Debug 构建、安装和真机截图回归。

重点回归场景：延迟解析期间的 loading 截图、解析成功后的扫描图标、格式/画质菜单打开与选择、长画质列表、加入队列后的真实标题、应用重启后的标题恢复，以及 Windows 与 Android 两套壳层的相同行为。

执行记录（2026-09-14）：

- Windows `.build/windows-kirigami-sdk` Release 重新编译通过，`ctest --test-dir .build/windows-kirigami-sdk -C Release --output-on-failure` 结果为 10/10；Qt Quick Controls 2 回退构建 `.build/windows-qt683-final` 的 CTest 为 6/6；两套壳层 offscreen 启动均保持运行 8 秒且未提前退出。
- Android arm64 Debug APK 重新生成并覆盖安装到 Xiaomi `24094RAD4C`（Android 14 / API 34），实机验证了解析中环形 loading、状态文字与加载条分行、静态扫描框、MP4/MP3 弹层文字和选择交互，以及加入队列后显示 `sample-3s` 标题。
- 本轮实现只使用 QML/C++ 内置能力；生成的位图参考图不进入应用资源，不增加运行时依赖。

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
- [x] 为 AppImage 补充应用图标和 `Icon` 元数据（后续按产品反馈移除，不再作为发布依赖）。
- [x] 规范化 Linux Bash 打包脚本的 LF 换行。
- [x] Windows Kirigami 页面组件化 Release 构建通过，CTest 保持 6/6。
- [x] 复用 Android arm64-v8a full-runtime 构建目录完成回退构建，确认 `RECLIP_ENABLE_KIRIGAMI=OFF` 时不编译桌面 Kirigami 页面。

#### 窄桌面与移动端菜单执行目标（2026-09-13）

- [x] 新增共享 `MobileHeader`，在左上角提供圆形汉堡菜单按钮；设置入口不再占用底部导航区域。
- [x] 新增共享 `MobileSettingsDrawer`，从左侧滑入现有 Android/iOS 设置页；保留系统返回键和点击遮罩关闭抽屉。
- [x] Qt Quick Controls 2 移动壳层移除 `MobileBottomBar`，Kirigami 窄桌面页也移除底栏；宽桌面侧栏和主内容下载/队列逻辑不变。
- [x] Windows Kirigami Release QML 编译、Android arm64 Debug 打包和启动验证通过；Android 使用 `RECLIP_ENABLE_KIRIGAMI=OFF` 时仅打包共享顶部菜单和设置抽屉组件。

#### Kirigami 组件化执行记录（2026-09-06）

- 桌面入口仍由 `MainKirigami.qml` 负责，颜色令牌继续来自共享的 `Theme.qml`，避免 Kirigami 默认主题覆盖 Windows 浅色或 Android Graphite Rose 视觉方向。
- `qml/kirigami/` 只在 `RECLIP_HAS_KIRIGAMI` 为真时加入 `qt_add_qml_module`；Android 构建脚本继续传入 `-DRECLIP_ENABLE_KIRIGAMI=OFF`。
- 新页面分别复用 `LinkCapture`、`MediaPreview`、`DownloadStatusPanel` 和 `DownloadRow`；工具诊断组件已从 QML 资源移除，因此第三方 UI 替换没有复制下载业务逻辑。
- `MainKirigami.qml` 在 `560–1059 px` 的窄桌面和移动分支使用共享顶部菜单/设置抽屉，宽桌面继续使用侧栏，并自动隐藏右侧活动栏以保留主内容宽度。
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

- [x] 将桌面三栏工作台重组为手机页面栈和左侧设置抽屉，而不是简单缩放桌面布局。
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

#### Android 真机回归记录（2026-09-12）

- [x] 当前连接设备为 Xiaomi `24094RAD4C`（Android 14 / API 34 / `arm64-v8a`），ADB 状态为 `device`。
- [x] 本轮使用设备上已安装的 `com.reclip.videodownloader` `versionName=0.1`、`targetSdk=35` 包；冷启动、主界面渲染和设置页导航成功，设置页中 yt-dlp 与 FFmpeg 均显示“已就绪”。
- [x] 通过本机受控的 **0.4 秒** MPEG-4/AAC fixture 和 `adb reverse` 完成真实解析、错误重试和 MP4 下载；UI 进入“下载完成/100%”，应用私有目录中的输出为 5,222 bytes，`ffprobe` 确认 MP4 容器、MPEG-4 视频和 AAC 音频流。该测试是 MP4 原样下载，不能单独作为 FFmpeg 转码成功的证据。
- [x] 使用 `wm user-rotation lock 1` 验证横屏布局，UIAutomator 返回 `rotation=1` 且横屏截图正常；测试后恢复 `wm user-rotation free` 和竖屏状态。
- [x] 本轮 `logcat` 未发现 `FATAL EXCEPTION`、`SIGSEGV`、`SIGABRT`、`UnsatisfiedLinkError` 或 `NoSuchMethodError`；测试服务器和 ADB reverse 映射已清理。
- [x] 后续继续任务已补齐本机 Qt 6.8.3 Android arm64 Kit、JDK 17、SDK API 35、Build Tools 35 和 NDK r26b，并从当前工作树成功生成包含 yt-dlp/FFmpegKit 的 Debug APK。详见 [当前工作树真机回归](docs/android-real-device-2026-09-12.md)。
- [x] 手机确认 USB 安装后，新 APK 安装返回 `Success`；独立包 `com.reclip.videodownloader.dev` / `Video Downloader Dev` 与旧应用并存，设备 APK 的 SHA-256 与当前工作树交付 APK 一致，旧应用及数据保持不变。
- [x] 当前 APK 真机完成单次 MP3 转换：日志确认 AAC → `libmp3lame`，进程内加载 `libffmpegkit.so` / `libavcodec.so`；真实输出 13,722 bytes、3.018594 秒、44.1 kHz MP3，完整解码通过。
- [x] 当前 APK 通过真实 QML 入口添加两个限速任务：先 MP3、后 MP4。日志确认第一项转换成功后才请求第二项，两项均完成；MP4 哈希与源文件一致，前台服务正常启动并退出。
- [x] 当前 APK 通过横竖屏、Home 后恢复和无活动下载时的进程重启检查；重启后两项完成状态与文件保留，未捕获 Java/native 崩溃签名。测试服务器/reverse 已停止清理，旋转设置已恢复；详见回归报告中的证据和限制。

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

### 优先级 P1：桌面端 FFmpeg SDK 内嵌改造 —— 执行中（2026-09-12）

目标是在桌面端保留 `yt-dlp` 的站点解析能力，同时将 FFmpeg 的媒体探测、封装、合并和转码能力以内嵌 SDK 的方式接入 C++ 程序，减少 FFmpeg/FFprobe 外部进程和独立命令依赖。

#### 改造边界

- 改造前的桌面 `DownloadManager` 通过 `QProcess` 启动 `yt-dlp`，并通过 `--ffmpeg-location` 让 `yt-dlp` 调用 FFmpeg；`ToolLocator` 同时检测 `yt-dlp`、`ffmpeg` 和 `ffprobe`。SDK 接入后的实际完成范围见本节执行记录。
- 本 FFmpeg 阶段只内嵌 FFmpeg，桌面 `yt-dlp` 继续作为外部进程负责网站解析、格式发现和真实媒体地址获取。
- Python/yt-dlp 内嵌与全链路子进程消除不纳入本 FFmpeg 阶段，另见下方 [yt-dlp 内嵌计划](#ytdlp-embedded-plan)；不以重写网站解析器作为默认路线。
- 当前桌面端运行时目录中的 `ffmpeg.exe` 和 `ffprobe.exe` 不是开发 SDK；正式接入前需要准备 FFmpeg 头文件、导入库/静态库和对应运行时库。
- 桌面端优先支持 Windows x64/MSVC 2022，再补齐 macOS 和 Linux；Android 继续沿用现有 FFmpegKit 方案。

#### 目标数据流

```text
yt-dlp（输出 JSON/媒体 URL）
        ↓
Qt 网络层（下载媒体数据）
        ↓
FfprobeService（媒体探测） → FfmpegService（封装、合并、转码）
        ↓
MP4 / MP3 输出文件
```

#### 方案分层与职责

| 层级 | 责任 | 不负责的内容 |
| --- | --- | --- |
| `YtDlpResolver` | 启动 `yt-dlp`，读取 JSON，解析格式、媒体 URL、请求头和文件大小 | 不负责媒体封装、编码和最终文件写入 |
| `QtNetworkDownloader` | 下载渐进式 HTTP(S) 视频/音频，处理进度、重试、取消和临时文件 | 不负责网站解析和音视频编解码 |
| `FfprobeService` | 使用 `libavformat/libavcodec/libavutil` 提供 ffprobe 等价的容器、时长和流信息探测 | 不启动 `ffprobe` 命令，不负责下载和媒体写入 |
| `FfmpegService` | 使用 FFmpeg SDK 进行 remux、音视频合并和音频转码，并兼容复用同一探测实现 | 不直接了解 QML 页面和队列 UI |
| `ProcessFfmpegBackend` | 保留当前 `QProcess` 命令行实现，作为兼容回退路径 | 不与 SDK 实现共享 FFmpeg 上下文 |
| `DownloadManager` | 编排解析、下载、处理、持久化、状态和错误 | 不直接调用 `libav*` C API |
| `ToolLocator` | SDK 模式下报告 SDK 版本和状态；回退模式下检测 FFmpeg 可执行文件 | 不参与具体媒体处理 |

推荐的依赖方向是：`DownloadManager → MediaBackend → FfmpegService`，而不是让
`DownloadManager` 直接持有 `AVFormatContext`、`AVCodecContext` 等 FFmpeg 类型。
这样可以让 SDK 方案和旧命令行方案共存，并避免把 FFmpeg 结构体扩散到业务层。

#### 下载链路详细设计

1. 校验用户输入 URL，默认使用 `--no-playlist`，不处理 DRM、登录绕过或未授权内容。
2. 启动 `yt-dlp` 输出单个 JSON，至少读取 `format_id`、`url`、`protocol`、`ext`、`vcodec`、`acodec`、`filesize`、`http_headers` 和 `requested_formats`。
3. 在 C++ 中选择格式并生成不可变的 `ResolvedMedia` 对象；解析完成后立即开始下载，避免媒体 URL 过期。
4. 对单文件、渐进式 HTTP(S) 格式，使用 `QNetworkAccessManager` 写入 `.part` 临时文件。
5. 对独立视频流和音频流，分别下载到临时目录；下载完成后交给 SDK 做 stream-copy 合并。
6. 对 MP4 不兼容的音频编码或用户选择 MP3 的场景，调用 SDK 的转码流程；能 remux 时不重新编码。
7. 对 yt-dlp 标记为 HLS/DASH/分段协议的 HTTP(S) 输入，使用 `FfmpegService::InputSource` 交给 `libavformat` 读取播放列表和分片；不经过外部 FFmpeg/下载器进程。
8. 处理完成后先校验输出存在、大小和媒体流信息，再执行原子替换，并更新队列持久化状态。
9. 取消、网络失败、磁盘不足或 SDK 失败时保留可诊断错误，清理本次生成的临时文件，不覆盖已有目标文件。

当前 MVP 已在受控 HLS/DASH VOD fixture 上验证 `libavformat` 网络输入，但不承诺直播、加密、DRM、
鉴权或所有真实网站格式；未验证的容器、协议和需要重新编码的视频仍按严格/兼容模式能力矩阵处理。

#### FFmpeg SDK 模块设计

建议新增以下目录和职责，具体命名可在实现阶段根据现有 C++ 风格微调：

```text
src/ffmpeg/
  FfmpegTypes.h       # 业务可用的媒体信息、流信息、错误和进度类型
  FfprobeService.h    # ffprobe 等价的 SDK 探测接口
  FfprobeService.cpp  # 探测入口、版本信息和共享生命周期适配
  FfmpegService.h     # SDK 对外接口
  FfmpegService.cpp   # remux、转码和合并实现；保留 probe 兼容入口
  FfmpegContext.h     # AV* 上下文的 RAII 包装
  FfmpegLogging.h     # FFmpeg 日志到 Qt 日志的适配
  FfmpegBackend.h     # DownloadManager 使用的后端抽象
```

接口草案如下，最终接口不向业务层暴露 FFmpeg 原生指针：

```text
FfprobeService::probe(input) -> MediaInfo
FfprobeService::runtimeVersion() -> QString
remux(videoInput, audioInput?, output, options) -> OperationResult
transcodeAudio(input, output, AudioOptions) -> OperationResult
cancel(jobId)
```

FFmpeg API 对应关系：

- ffprobe SDK：`avformat_open_input`、`avformat_find_stream_info`、流和时长读取；不启动 `ffprobe` 可执行文件。`FfmpegService::probe` 仅保留为既有调用方的兼容入口。
- remux：`avformat_alloc_output_context2`、`avformat_new_stream`、`avcodec_parameters_copy`、`av_interleaved_write_frame`。
- 解码/编码：`avcodec_send_packet`、`avcodec_receive_frame`、`avcodec_send_frame`、`avcodec_receive_packet`。
- 音频转换：`SwrContext` 和 `libswresample`；必要时再引入 `libavfilter`。
- 时间戳：所有跨输入输出的 packet 使用 `av_packet_rescale_ts`，并检查负时间戳和 DTS/PTS 单调性。

#### 线程、进度和取消策略

- 每个媒体处理任务使用独立 worker，不在 GUI 线程调用阻塞式 FFmpeg API。
- FFmpeg 上下文只在所属 worker 线程创建和销毁，不跨线程传递 `AV*` 指针。
- `QNetworkReply` 的网络取消和 FFmpeg 的 `AVIOInterruptCB` 使用同一个可取消任务状态。
- 进度分为 `resolving`、`downloading-video`、`downloading-audio`、`processing`、`finalising` 五个阶段；只有原子替换成功后才报告 100%。
- 网络阶段使用已知 `Content-Length` 或 yt-dlp 的文件大小；处理阶段根据输入时长和已处理 packet 估算，无法估算时报告阶段状态而不是伪造百分比。
- 所有回调先转换为 Qt 的值类型，再通过 queued connection 更新 `DownloadManager` 和 QML。
- 一个任务只能有一个终止结果；完成、失败、取消之间使用状态机防止重复信号和重复清理。

#### CMake 与 SDK 目录约定

开发包不直接提交到仓库，统一通过本地变量或 CI 产物提供。推荐目录结构：

```text
.third_party/ffmpeg/<platform>-<arch>/
  include/libavcodec/...
  include/libavformat/...
  lib/                         # MSVC .lib 或对应平台导入库
  bin/                         # 动态链接时的 DLL/dylib/so
  LICENSE/
  build-info.txt
```

计划增加的构建配置：

- `RECLIP_ENABLE_FFMPEG_SDK`：是否编译 SDK 后端。
- `RECLIP_FFMPEG_ROOT`：开发包根目录。
- `RECLIP_FFMPEG_LINKAGE`：首版固定为 `shared`，静态链接暂不作为默认方案。
- `RECLIP_HAS_FFMPEG_SDK`：由 CMake 检测结果生成的编译宏。

CMake 阶段需要完成：

1. 检查所有必需头文件、导入库和运行库是否来自同一版本。
2. 使用 imported target 集中声明 FFmpeg 库及其系统依赖，不把库路径散落在业务 target 中。
3. SDK 模式缺少开发包时给出明确错误；`auto/fallback` 模式则回退到现有命令行实现。
4. Windows、macOS、Linux 分别验证符号导出、运行库搜索路径和架构，不混用不同编译器生成的二进制。
5. 记录 FFmpeg 源码版本、构建参数、编译器、目标架构和许可证文件，供打包和发布检查使用。

#### SDK 模式与回退模式

后端选择顺序固定为：

```text
显式启用 SDK且运行库完整 → FfmpegSdkBackend
SDK未启用或开发包缺失      → ProcessFfmpegBackend
SDK处理遇到暂不支持格式    → 当前任务回退到 ProcessFfmpegBackend
```

回退必须发生在任务真正开始写最终文件前，不能在 SDK 已经部分写入目标文件后直接复用同一路径。
两种后端共用 `ResolvedMedia`、队列状态、进度阶段和错误分类，以降低行为差异。

#### 持久化与恢复

- 队列任务增加 `backend`、`processingStage`、`temporaryInputs` 和 `selectedFormats` 等内部字段，原有 JSON 增加 schema 版本。
- 应用重启时，`resolving` 和 `downloading` 状态按现有策略恢复；处于 `processing` 的 SDK 任务标记为 `interrupted`，不假设 FFmpeg 上下文可以恢复。
- `.part`、视频临时文件和音频临时文件均使用任务 ID 命名，避免多个任务互相覆盖。
- 启动时清理超过保留时间且不属于活动任务的临时目录；清理失败只记录警告，不阻塞应用启动。
- 输出文件采用同目录临时文件加原子重命名，跨卷输出或 Android SAF 场景仍走各平台现有导出逻辑。

#### 实施阶段

- [x] 阶段 1：准备 FFmpeg 开发包，确认 Windows x64/MSVC 2022 的 ABI、编译参数、版本和许可证；默认使用不启用 GPL/nonfree 组件的动态链接构建。
- [x] 阶段 2：增加 `RECLIP_ENABLE_FFMPEG_SDK` 和 `RECLIP_FFMPEG_ROOT` CMake 配置，建立 `FfmpegSdk` target，集中声明 `libavformat`、`libavcodec`、`libavutil`、`libswresample` 和 `libswscale` 依赖。
- [x] 阶段 3：新增 `src/ffmpeg/FfmpegService.h/.cpp`，完成上下文生命周期、错误转换、进度回调、后台线程执行和可中断取消令牌。
- [x] 阶段 4：完成 `FfprobeService::probe()`（并保留 `FfmpegService::probe()` 兼容入口）、MP4 stream-copy remux、MP3 转码，以及独立视频/音频流合并；FFmpeg 结构体仍只在封装层内部使用。
- [x] 阶段 5：`DownloadManager` 和桌面 `DownloadQueue` 已接入 yt-dlp JSON/URL、Qt 网络下载、SDK 后处理和命令行回退；`MediaInspector` 仍按职责使用 yt-dlp，不重复引入 FFmpeg 逻辑。
- [x] 阶段 6：`ToolLocator` 在 SDK 模式下将 FFmpeg/FFprobe 标记为内嵌运行时，同时保留 yt-dlp 检测和命令行回退路径。
- [~] 阶段 7：Windows SDK 便携包脚本、运行时 DLL、许可证和构建记录已完成；macOS/Linux 打包入口尚待按各平台 SDK 方案接入。
- [~] 阶段 8：已增加本地媒体 fixture、探测、remux、MP3 转码、合并 MP4、独立双流、Qt 网络下载、队列、异常清理、受控 HLS/DASH VOD SDK 网络输入、进度/取消 API 和 SDK/回退双配置测试；直播/加密协议、真实慢速网络取消、磁盘错误矩阵和更广泛格式仍需补齐。

#### 已完成的步骤（2026-09-12）

- 使用 BtbN `ffmpeg-n9.0-latest-win64-lgpl-shared-9.0.zip` 作为 Windows x64 开发包，校验 SHA-256 后整理到 `.third_party/ffmpeg/windows-x64`；包内包含头文件、MSVC import `.lib`、运行时 DLL 和许可证文件。
- 新增 `cmake/FindFFmpeg.cmake`，通过 imported targets 集中管理 `avformat`、`avcodec`、`avutil`、`swresample` 和 `swscale`，并增加 `RECLIP_ENABLE_FFMPEG_SDK`、`RECLIP_FFMPEG_ROOT` 开关。
- 新增 `src/ffmpeg/FfmpegSdk.*` 和 `tests/ffmpeg_sdk.cpp`，完成 FFmpeg C API 版本探针；Windows Release 和 Debug 均已编译并运行通过，现有 6 个回归测试也保持通过。
- 新增 `FfmpegService` 本地媒体服务，完成本地 probe、stream-copy remux、音频重采样和 MP3 编码；测试运行时生成 WAV，不依赖外部 FFmpeg 命令。
- 新增显式 `FfprobeService` SDK facade；它复用同一 `libavformat` 输入生命周期，提供 ffprobe 等价媒体信息和 FFmpeg/FFprobe SDK 版本探针。SDK 模式下 `ToolLocator` 清空 ffprobe 外部路径并报告“内嵌 FFprobe SDK”，兼容模式和用户自定义路径仍走原命令行检测。
- 桌面 SDK 模式已接入 `DownloadManager`：单一合并流由 yt-dlp Python 原生下载器写入任务临时文件后交给内嵌 SDK 封装/转码；原生下载失败时严格内嵌回退 Qt 网络层；独立双流由 Qt 网络层分别下载后交给 SDK 合并；识别出的分段 HTTP(S) 输入直接交给 FFmpeg SDK 的 `libavformat`。
- 已加入固定的音视频 MP4 fixture、本地 HTTP 测试服务器和 fake yt-dlp JSON，验证合并 MP4 的 SDK 下载链路、输出流探测、临时文件清理，以及 HLS/DASH VOD 播放列表和媒体片段的 SDK 网络输入。
- 已将桌面 `DownloadQueue` 接入 `DownloadManager` 的 SDK 后端，队列任务现在按顺序复用内嵌 FFmpeg；队列级测试覆盖 SDK MP4 下载和输出探测。
- `FfmpegService` 增加 `OperationOptions`：支持处理进度回调、FFmpeg interrupt callback 和原子输出取消；`DownloadManager` 使用线程安全取消令牌将 UI 取消动作传入 worker。
- SDK 下载测试已覆盖合并媒体和 `requested_formats` 独立视频/音频媒体两条路径；服务测试覆盖进度回调、取消结果和临时输出不落地。
- `ToolLocator`、Windows SDK 打包脚本和第三方声明已同步更新；内嵌便携包不携带 `yt-dlp.exe`、命令行 FFmpeg 或 FFprobe，兼容模式工具另行保留。
- SDK 配置下当前 CTest 为 10/10，关闭 SDK 的回退构建为 6/6；最新 Windows SDK 便携包已生成于 `.artifacts/windows/ReClip-Release-ytdlp-ffprobe-sdk-settings-clean`。设置页工具诊断已移除，运行时后端和兼容路径仍保留。仍未宣称全部阶段完成：直播/加密协议、真实慢速网络取消、磁盘错误矩阵、macOS/Linux 打包和干净机复验仍需下一步实现。

#### 里程碑、产物和退出条件

| 里程碑 | 主要工作 | 必须产物 | 退出条件 |
| --- | --- | --- | --- |
| M0 方案冻结（已完成） | 确认平台、FFmpeg 版本、动态/静态链接和 yt-dlp 边界 | 技术决策记录、格式支持矩阵 | 许可证与 ABI 方案没有未决阻塞项 |
| M1 SDK 可链接（已完成） | 完成开发包、CMake target 和最小探测程序 | `FfmpegSdk` target、SDK 版本输出 | Windows Debug/Release 能链接并运行 probe |
| M2 本地媒体链路（已完成） | 实现本地文件 probe、remux、MP3 转码 | `FfmpegService`、音频/合并 MP4 fixture | 音频、合并和独立双流基础链路通过 |
| M3 单文件下载（基础完成） | yt-dlp JSON、Qt 网络下载、临时文件和原子输出 | SDK 单文件 MP4/MP3 后端、回退分支 | 基础成功/失败/回退和 worker 取消 API 已通过；真实网络取消、磁盘矩阵待补 |
| M4 音视频合并（基础完成） | 独立视频/音频流下载、时间戳处理和 stream-copy | 合并后 MP4、流信息校验 | 合并和独立双流 fixture 通过；更广泛时间戳/格式矩阵待补 |
| M5 应用集成（基础完成） | 接入队列、设置、下载引擎状态、后台 worker 和错误提示 | QML 可见状态、队列 SDK 后端、持久化 | 直接下载与桌面队列已接入；应用重启和多任务压力矩阵待补 |
| M6 发布切换 | 打包、许可证、CI、回退和干净机验证 | 三平台包、构建说明、第三方声明 | SDK 模式和回退模式都能从 CI 产出 |

每个里程碑完成后再扩大格式范围；如果某一里程碑的 SDK 结果与旧流程不一致，先保留回退，不跨阶段引入新的格式或平台复杂度。

#### 格式支持矩阵（初始版本）

| 输入类型 | 首版策略 | 后续策略 |
| --- | --- | --- |
| 单文件 HTTP(S)，同时含视频和音频 | yt-dlp Python 原生下载 + SDK remux；失败时 Qt 下载回退 | 增加断点续传和更细的校验 |
| 独立视频流 + 音频流 | 分别下载 + SDK 合并 | 优化并行下载和磁盘占用 |
| 音频转 MP3 | SDK 解码、重采样、编码 | 增加更多输出格式和码率选项 |
| HLS/DASH 分段流 | 已接入 FFmpeg SDK 的 `libavformat` 网络输入；受控 HLS/DASH VOD fixture 已验证 | 补齐直播/加密/鉴权和真实网站矩阵；不把受控 fixture 结果扩展为全部协议支持 |
| 视频编码或容器不兼容 | 暂时回退，避免隐式高耗时转码 | 增加明确的转码能力和资源提示 |
| DRM、登录绕过和受限内容 | 不支持 | 不纳入项目目标 |

#### 主要风险与应对

- **FFmpeg ABI 不一致**：头文件、导入库和 DLL 必须来自同一构建；CMake 配置阶段检查版本和架构，运行时记录加载库版本。
- **网站 URL 过期**：解析后立即下载，避免把 `ResolvedMedia` 长时间放在队列中；过期时重新解析而不是重复使用旧 URL。
- **请求头/鉴权差异**：首版只复制 yt-dlp JSON 中明确提供的 HTTP 请求头，不自行保存或猜测 Cookie；失败时回退并给出可诊断信息。
- **时间戳和容器兼容性**：所有输入输出时间基统一通过 `av_packet_rescale_ts` 转换，并在写入前检查 DTS/PTS 单调性。
- **内存和磁盘占用**：首版优先临时文件和 packet 流式处理，不把完整媒体读入内存；启动和处理前检查剩余空间。
- **取消不彻底**：Qt 网络请求、FFmpeg interrupt callback、worker 状态和最终文件清理必须绑定同一个 job ID。
- **许可证误判**：以实际 FFmpeg 源码构建参数为准，不直接把某个预编译 `essentials` 包标成 LGPL；发布前由构建记录和第三方声明共同校验。
- **回退行为差异**：SDK 和命令行后端共用格式选择、队列状态和错误枚举，回退只更换媒体处理实现。

#### 默认技术决策

- 首版使用动态链接 SDK，优先降低静态链接带来的程序体积和许可证合规风险；动态链接不代表完全没有依赖，仍需随包发布 FFmpeg DLL。
- 迁移期保留桌面 `yt-dlp` 外部进程兼容路径；严格 SDK 模式逐步迁移到 Python API 和宿主 FFmpeg SDK，保留上游网站解析能力。
- SDK 和旧命令行实现并行保留，SDK 通过构建选项控制，确保缺少开发包时仍能构建和运行。
- 使用临时输出文件和原子替换，避免取消或崩溃后留下损坏的目标文件。
- 许可证方案必须在发布前根据实际 FFmpeg 构建参数确认；FFmpeg 基础代码通常为 LGPL，但启用 GPL 组件后整体授权要求会变化。

#### 验收标准

- [~] SDK 模式下 Windows Release 构建、直接下载、受控 HLS/DASH 和桌面队列流程已通过；已验证路径不启动 FFmpeg/FFprobe 命令行进程，直播/加密/未验证分段场景仍按能力矩阵处理。
- [~] `yt-dlp` 负责解析并在单流场景执行原生下载，MP4、MP3 及音视频合并的基础 SDK 结果已通过；多格式下载、更多网站和长任务矩阵仍待验证。
- [~] SDK 模式和回退模式均通过 CTest，失败、取消 API 和临时文件清理已覆盖；真实慢速网络取消及磁盘错误仍待专门测试。
- [~] Windows SDK 便携包已生成并将 FFmpeg SDK DLL 随应用发布；无全局 FFmpeg 的干净机启动仍需在隔离机复验。
- [x] 发布包已包含与实际 FFmpeg 二进制匹配的 LGPL 构建许可证和 `FFmpeg-SDK-build-info.txt` 来源/校验记录。

#### 参考资料

- [FFmpeg API 文档](https://ffmpeg.org/doxygen/trunk/index.html)
- [FFmpeg 许可证与 LGPL/GPL 说明](https://ffmpeg.org/legal.html)

<a id="ytdlp-embedded-plan"></a>

### 优先级 P1：yt-dlp SDK 内嵌与下载引擎统一 —— Windows 解析/基础下载已接入，Android 协议已对齐，继续分阶段验收（2026-09-12）

#### 目标与现状

目标是将桌面端启动 `yt-dlp` 可执行文件的方式，逐步替换为应用进程内的 Python API 调用，并与现有 FFmpeg SDK 配合。用户无需自行安装 Python、yt-dlp 或配置系统 PATH；这属于随应用内置依赖，不代表消除 Python 运行时，也不承诺安装包或内存占用更小。

- [x] 已检查当前桌面 `MediaInspector`、`DownloadManager` 和 `ToolLocator`：兼容构建或显式自定义工具路径仍保留 `QProcess`；严格 SDK 构建的解析、单流下载和 FFmpeg 处理路径不依赖这些命令行工具。
- [x] 已检查当前 Android bridge 和固定的 `yt-dlp-android:2.0.2` AAR：通过 Chaquopy/CPython 3.13 在应用进程内调用 Python；解析直接调用 `YoutubeDL.extract_info()`，下载通过 Java API 调用 `ytdlp_runner` 模块。`executeDebug()` 并不等于启动可执行文件。
- [x] 已确认方案采用官方 `YoutubeDL` Python API 与 CPython 嵌入接口，不将重新打包 `yt-dlp.exe` 视为 SDK 内嵌，也不以 C++ 重写上游网站解析器。
- [~] 桌面 CPython 解析后端已接入 `MediaInspector`、工具探测及 `DownloadManager`；单一合并流优先由 yt-dlp Python 原生下载器写入任务临时文件，再由 FFmpeg SDK 后处理，多流/HLS/DASH 仍按能力矩阵分流。Android JNI 请求/结果协议已对齐，设备端取消后的 Python worker 退出确认和 OS 级零子进程验收仍未完成。详见本节执行记录与 [运行时说明](docs/yt-dlp-embedded.md)。

当前 Android 的基础内嵌链路和本地媒体真机回归不能证明所有网站、HLS/DASH 或 YouTube JavaScript 解析均不产生子进程。

#### 分层目标与范围

1. **目标 A：yt-dlp 本体进程内调用。** 优先 Windows x64/MSVC，随后 macOS/Linux；Android 复用现有 Chaquopy 后端。此目标不自动宣称 JavaScript 引擎及所有后处理均无子进程。
2. **目标 B：已声明支持场景全链路零子进程。** 审计并替换外部 JavaScript、FFmpeg/FFprobe、外部下载器和其他辅助命令；只有通过对应站点/协议矩阵后才标记完成。
3. iOS 暂不扩大现有能力范围；移动端商店发布、动态代码更新及平台合规另行评估。
4. FFmpeg 既有待办（跨平台打包、真实网络取消、磁盘异常等）继续保留，不能用 yt-dlp 阶段完成替代其验收。

#### 目标架构与接口

```text
MediaInspector / DownloadManager / DownloadQueue
                    ↓
              YtDlpService
                ├─ EmbeddedPythonBackend：桌面 CPython C API
                ├─ AndroidPythonBackend：JNI → 现有 Chaquopy
                └─ ProcessYtDlpBackend：迁移期兼容实现
                    ↓（内嵌后端）
       Python 适配层 → yt_dlp.YoutubeDL
                    ↓
          原始媒体文件 / 下载结果
                    ↓
       FfmpegService / Android FFmpegKit
                    ↓
             校验并发布 MP4 / MP3
```

已新增 `src/ytdlp/`，集中放置服务、业务类型和桌面 Python 生命周期管理；Python 适配代码位于 `runtime/python/reclip_ytdlp/` 并编入 Qt 资源。当前服务实现解析/探测和单一格式原生下载的内嵌与进程分支；`DownloadManager` 已将直链单流接入该下载接口，多流与分段输入仍由宿主编排。Android bridge 保留平台专用调用入口，但其 JNI 终态已使用同样的请求 ID、JSON 产物和错误码语义。

对外接口草案：

```text
inspect(request) -> requestId
download(request) -> requestId
cancel(requestId)
runtimeInfo() -> backend / Python版本 / yt-dlp版本 / 加载状态
capabilities() -> 支持协议 / JS能力 / 是否允许兼容子进程
signals: metadataReady / progress / finished / failed / cancelled
```

- 业务层仅接收 Qt 值类型，不持有 `PyObject*`、JNI 对象或 Python 异常实例；统一请求 ID、错误分类、输出文件清单及终止状态。Android 完成结果 JSON 至少包含输出路径、字节数、格式和后端标识。
- 返回的媒体对象至少包含格式 ID、容器、编解码器、协议、请求头、时长、大小及选中的音视频流；未知大小/时长保留未知，不伪造数值。
- Python 内保留下载所需的完整上下文；跨边界优先选取所需字段，使用 JSON 时先调用 `YoutubeDL.sanitize_info()`，不直接假设 `extract_info()` 结果可序列化。上游有明确说明，见 [官方嵌入示例](https://github.com/yt-dlp/yt-dlp#embedding-yt-dlp)。
- 通过 `progress_hooks`、受控日志适配和结构化输出清单传回进度/结果，不再靠普通日志文案或“目录里最新文件”判断任务产物。
- 桌面与 Android 先统一协议和测试，再评估共享 Python 适配包；当前 Android AAR 包含预编译 Python，不能假定新增本地 `.py` 会自动进入该 AAR。自建 Chaquopy 打包或维护可复现 AAR 构建属于后续明确工作项。

#### 下载与 FFmpeg SDK 协作

1. 保留原始网页 URL 和用户选择的格式策略，在队列任务实际开始时解析；过期媒体 URL 应重新解析，不长期持久化为可恢复凭据。
2. 单一合并流优先使用 yt-dlp 自带的 Python 原生下载器，并将解析返回的请求头传入同一次下载；若该直链不适合原生下载，严格内嵌模式回退到已验证的 Qt HTTP(S) 路径。多流合并和分段输入不强行塞入单流接口。
3. MP3 下载原始音频后交给 FFmpeg SDK；分离音视频分别写入任务专属临时目录，再由 SDK 合并，避免 yt-dlp 自动选择外部 FFmpeg 合并路径。
4. 不直接启用默认 `FFmpegExtractAudio` 等外部后处理器。合并、修复、封装、元数据及容器兼容性检查需逐项接管；仅清空显式 `postprocessors` 不能作为“不会启动 FFmpeg”的证明。
5. HLS/DASH 按具体协议、分片和容器能力决定使用 Python 下载器或 SDK；直播、特殊传输及未验证格式不默认承诺支持。
6. 请求头、代理和用户明确提供的 Cookie 应在解析/下载之间保持一致；不得自行读取浏览器凭据。日志和持久化记录需隐藏敏感请求头、签名 URL 和凭据。
7. 只有输出存在、媒体流校验通过并完成最终文件发布后才报告完成；失败/取消只清理本任务拥有的临时文件，不删除用户已有文件。

#### 解释器、线程与取消

- 桌面采用进程级解释器生命周期与专用后台执行器，首版串行调度 Python 操作，限制队列积压；不在 QML/GUI 线程运行阻塞 Python 调用，不每个任务反复初始化/销毁解释器。
- 使用 `PyConfig` 的隔离配置，显式设置应用私有运行时路径，不依赖系统 Python、用户 site-packages 或当前目录。隔离配置不等于安全沙箱。参见 [CPython 初始化配置](https://docs.python.org/3/c-api/init_config.html#isolated-configuration)。
- 明确 GIL、引用计数、异常转换和销毁顺序；回调通过 Qt queued connection 返回界面，等待异步媒体处理时避免持有 GIL 造成死锁。
- 取消令牌必须贯穿解析、下载、重试等待和 FFmpeg 阶段：下载 hooks 检查取消，解析阶段还需有界网络超时及必要的适配检查点。Android bridge 会在 worker 收尾后发送取消终态，但 Java `Future.cancel(true)` 或 Qt 定时器超时本身不自动证明 Python 已停止；设备端仍需补充时序证据。
- 不使用强杀线程或无约束的异步 Python 异常注入。区分“请求取消”与“工作线程确认退出”，资源释放前不能宣称安全完成清理，也不能复用该任务目录。
- 每个请求最多一个终止结果；迟到回调按请求 ID 和代际丢弃。退出应用时先停止接收任务、取消并等待 worker，最后处理解释器销毁。
- 进程内原生依赖崩溃可能影响整个应用，无法保留原有子进程故障隔离；通过依赖固定、压力测试、崩溃日志和明确的兼容模式降低风险。

#### 全链路零子进程的专项工作

当前上游完整 YouTube 支持涉及 `yt-dlp-ejs` 与 JavaScript 引擎；其 QuickJS provider 仍通过 `Popen` 调用可执行文件。因此“嵌入 CPython + 安装 EJS”不等于解决 JavaScript 子进程依赖。依据：[EJS 文档](https://github.com/yt-dlp/yt-dlp/wiki/EJS)、[QuickJS provider 源码](https://github.com/yt-dlp/yt-dlp/blob/master/yt_dlp/extractor/youtube/jsc/_builtin/quickjs.py)。

- [ ] 调研并验证内嵌 QuickJS/QuickJS-NG 与 EJS 的兼容性，包括运行时能力、脚本输入输出、性能和目标平台构建。
- [ ] 通过受控的 provider/适配层连接 yt-dlp 与内嵌 JS 引擎，尽量缩小对上游内部接口的依赖；版本升级必须运行兼容测试。
- [ ] JS 执行设置时间、内存和中断限制，不暴露不必要的文件系统/网络接口；脚本依赖随包固定，首版不默认远程下载执行代码。
- [ ] 审计 yt-dlp 的外部下载器、自动修复/后处理、版本探测、插件及辅助命令路径；严格模式不允许未验证路径悄悄回退到子进程。
- [ ] 在测试中记录/阻断 Python 子进程入口，并配合操作系统进程创建观测；Python 层拦截只作为测试防线，不等于系统级安全隔离。

#### 构建、打包和迁移策略

- 拟增加 `RECLIP_ENABLE_YTDLP_SDK` 与 `RECLIP_PYTHON_ROOT`，通过 `Python3::Python` 等 CMake target 集中接入嵌入开发接口；Android 复用其运行时，不再链接第二份桌面 Python。
- 区分构建机 Python 与目标平台 Python，校验架构、版本、导入库/共享库和扩展模块 ABI；CPython 3.13 可作为与当前 Android 对齐的首个候选，正式版本在依赖矩阵验证后冻结。
- 随包提供必要标准库、yt-dlp、TLS/CA 证书及实际所需扩展；`curl_cffi`、Brotli、EJS 等按支持场景评估，不以“可选依赖”名义忽略站点能力差异。
- 首版通过构建阶段锁定依赖、哈希和来源，记录许可证及构建清单，随应用更新发布；不在用户首次启动时运行 `pip install`，不运行中替换已导入模块。Android 固定 AAR 的更新同样需要重新构建和验收。
- 迁移期保留 `ProcessYtDlpBackend`，显式区分“严格内嵌模式”与“兼容模式”。严格模式缺少运行时或能力不足时明确失败；兼容模式才允许可见、可记录的外部进程回退，不能将其结果算入零子进程验收。
- 设置页不再展示工具诊断或外部工具路径；旧自定义工具路径仍由后端保留，用于兼容模式，不直接删除已有用户设置。
- Windows 验证后分别处理 macOS 包内库加载/签名和 Linux 运行库搜索路径及兼容性；记录体积、冷启动耗时、内存及重复任务后的增长情况，不预设性能收益。

#### 实施里程碑与退出条件

以下状态按本轮实际结果更新；“部分完成”不表示整行退出条件均已满足，尤其不以原有 Android 真机或 fake yt-dlp 测试替代新增链路验收。

| 里程碑 | 工作与产物 | 退出条件 |
| --- | --- | --- |
| T0 接口与基线（部分完成） | 已建立桌面解析/探测服务和请求类型，保留进程分支；Android JNI 已对齐请求 ID、JSON 产物和错误码 | 现有解析、下载、队列和错误行为保持一致，SDK 开关关闭仍可构建并通过回归 |
| T1 Windows 内嵌解析（基础通过） | 固定 Python 开发/运行包，完成初始化、版本查询、`extract_info()` 及元数据转换 | Debug/Release 均可运行；没有全局 Python/yt-dlp 时基础解析成功；非法 URL、网络超时和运行库缺失可诊断；独立干净机与其他扩展缺失矩阵仍待补 |
| T2 下载与 SDK 衔接（部分完成） | 已接入 yt-dlp Python 单流原生下载、Qt HTTP(S) 回退、SDK MP4/MP3、受控 HLS/DASH VOD、取消、队列和独立临时文件；Python 多流下载与真实站点待办 | 受控 HTTP(S) 单文件、HLS/DASH VOD 与分离双流用例通过；输出可解码；支持路径不启动 `yt-dlp.exe`/`python.exe`/`ffmpeg.exe`/`ffprobe.exe` |
| T3 协议与 JS 验证 | HLS/DASH 能力矩阵、内嵌 JS provider 原型、真实授权站点测试 | 每项记录支持/不支持及原因；需要 JS 的已选站点通过后才宣称其零子进程支持；失败不阻塞已验收基础能力交付 |
| T4 跨平台与 Android 对齐 | macOS/Linux 构建打包；Android 协议、结构化结果已接入，待设备端取消确认和共享 Python 包评估 | 各平台独立记录验收结果；Android 真机解析、下载、队列、前台服务及生命周期不回归 |
| T5 发布切换 | 干净环境、进程观测、性能/压力、依赖更新回归及第三方声明 | 按目标 A/B 分别发布结论，严格模式与兼容模式行为可辨认；未通过的平台/场景明确保留待办 |

#### 已完成的步骤与验证（2026-09-12）

- [x] 新增依赖清单和 `Fetch-PythonRuntime.ps1`，固定 CPython 3.13.15、yt-dlp 2026.8.19、certifi 2026.7.22，并校验 NuGet SHA-512/PyPI SHA-256；只部署到项目私有目录。
- [x] 新增 `RECLIP_ENABLE_YTDLP_SDK`、私有运行库 staging、后台解释器、结构化结果和取消令牌；禁用默认外部 JS/远程组件和用户插件发现，显式格式选择避免隐式 FFmpeg 探测。
- [x] 桌面媒体解析、工具版本检测、SDK 地址解析与基础 MP4/MP3 下载/队列已使用内嵌路径；直链单流优先走 yt-dlp Python 原生下载器，失败时回退 Qt 网络输入；明确自定义可执行路径仍选择兼容后端。
- [x] 新增真实 yt-dlp + 本地 HTTP fixture 测试：覆盖非法 URL、404、URL 敏感参数隐藏、解析前/读取期间取消、超时、GUI 心跳、旧回调隔离、重复调用、单一格式原生下载、MP4/MP3 输出探测、同名文件保护及队列重启恢复。
- [x] Windows Release CTest 10/10、Debug 新内嵌测试 1/1、旧进程配置 CTest 6/6、Python 适配测试 5/5 通过；标准库缺失测试返回预期运行时错误。
- [x] 新增受控 HLS/DASH VOD fixture：yt-dlp 内嵌解析返回 m3u8/MPD 后，FFmpeg SDK `libavformat` 在进程内读取播放列表和媒体片段，并完成 MP4 封装；直播、加密和真实站点矩阵尚未宣称支持。
- [x] 生成实验性 Windows 便携包 `.artifacts/windows/ReClip-Release-ytdlp-sdk`，唯一可执行文件为主程序；在仅使用包内库和系统 PATH 的验证目录完成上述端到端测试，实际程序 offscreen 冷启动也通过。开发机上的此项检查不等于独立干净机验收。
- [x] 重新生成包含原生单流下载和 HLS/DASH SDK 网络输入的便携包 `.artifacts/windows/ReClip-Release-ytdlp-native-sdk`；包内功能测试和无效 Python 环境下的 offscreen 冷启动均通过。目录 3,016 个文件、约 244.61 MiB，主程序 SHA-256 为 `DFE8BB828488FC1B7ED21921B85AB911EE2AA5E7C5EE1E984CB3BFAEBE0AF5E2`；仍不是独立干净机验收。
- [x] 重新生成当前源码对应的最终便携包 `.artifacts/windows/ReClip-Release-ytdlp-native-sdk-final`；目录 3,016 个文件、约 244.62 MiB，主程序 SHA-256 为 `6AD5B5078CD4048C0EABB6DAC303EED1FAF2FE4D4C113AE4B96B438A3549AC1E`。完整包复制到隔离目录后，内嵌端到端测试和无效 Python 环境下的 offscreen 冷启动均通过；仍不是独立干净机验收。
- [x] 重新生成包含显式 `FfprobeService` 和输出后验探测的 Windows 便携包 `.artifacts/windows/ReClip-Release-ytdlp-ffprobe-sdk`；目录 3,016 个文件、约 244.62 MiB，主程序 SHA-256 为 `848702FEF90425B89962ECADB34B1C9B53DC5E63666D5B93BFD67CC2B3163F33`。完整包复制到隔离目录后，内嵌端到端测试、FFprobe SDK 输出校验和无效 Python 环境下的 offscreen 冷启动均通过；仍不是独立干净机验收。
- [x] 重新生成当前源码对应的 FFprobe SDK 最终 Windows 便携包 `.artifacts/windows/ReClip-Release-ytdlp-ffprobe-sdk-final`；目录 3,016 个文件、约 244.62 MiB（256,505,576 字节），主程序 SHA-256 为 `08401A7914044C13A3781E80520CADB6512B1DFFA262E46F3457B2806203CE9F`。`runtime-manifest.json` 标记 `ffprobeBackend=embedded-sdk`，包内唯一 `.exe` 为 `ReClip.exe` 且没有 `ffprobe.exe`；完整包复制到隔离目录后，内嵌端到端测试、FFprobe SDK 输出校验和无效 Python 环境下的 offscreen 冷启动均通过；OS 进程创建事件因当前权限不足未观测，因此仍不是独立干净机验收。
- [x] 重新生成移除设置页工具诊断后的 Windows 便携包 `.artifacts/windows/ReClip-Release-ytdlp-ffprobe-sdk-settings-clean`；目录 3,016 个文件、约 244.57 MiB（256,451,816 字节），主程序 SHA-256 为 `D1C4C7AAADF488F242DAAEBC3929106501965632C5DFC91B321B0C9D5B0110`。`runtime-manifest.json` 标记 `ffprobeBackend=embedded-sdk`，包内唯一 `.exe` 为 `ReClip.exe` 且没有外部工具可执行文件；完整包复制到隔离目录后，内嵌端到端测试、FFprobe SDK 输出校验和无效 Python 环境下的 offscreen 冷启动均通过；OS 进程创建事件因当前权限不足未观测，因此仍不是独立干净机验收。
- [x] 使用 `scripts/Install-Kirigami.ps1 -QtRoot D:\QT\6.8.3\msvc2022_64` 安装固定版本 Extra CMake Modules 6.8.0 和 KDE Kirigami 6.8.0；CMake 配置、运行库 DLL、`org.kde.kirigami` QML 模块和 `KF6KirigamiConfig.cmake` 均已写入 `.third_party/install`。
- [x] 新建 `.build/windows-kirigami-sdk`，以 `RECLIP_ENABLE_KIRIGAMI=ON`、FFmpeg SDK 和 yt-dlp SDK 配置并编译通过；构建输出已包含 Kirigami DLL 与 QML 模块，`MainKirigami.qml`、Kirigami 下载页、队列页和设置页均通过 QML 编译。
- [x] Kirigami-enabled Windows Release CTest 10/10 通过；仅使用构建输出中的 Kirigami 运行库/QML 模块和 Qt PATH 做 offscreen 启动检查，程序保持运行 8 秒且无启动崩溃，确认安装的 SDK 可被应用实际加载。上游模板扫描仍会提示可选 QML 示例的解析警告，不影响本项目构建。
- [x] 按当前 Kirigami 构建实际使用情况，通过管理员权限从官方 Vulkan SDK 1.4.357.0 安装器安装完整项目私有 SDK 到 `.third_party/vulkan-sdk/1.4.357.0`：包含 `spirv-opt`、`glslc`、`glslangValidator`、相关 SPIR-V/glslang 运行库，以及同版本 Vulkan `vulkan`/`vk_video` headers；安装器已配置机器级 `VULKAN_SDK` 和 Vulkan `Bin` PATH，CMake 已成功找到 `WrapVulkanHeaders`，Kirigami 已重新配置、编译并安装。
- [x] 使用完整 Vulkan SDK 重新配置并编译 `.build/windows-kirigami-sdk`；FFmpeg SDK、CPython/yt-dlp SDK、Kirigami 和 Vulkan headers/tools 均被实际纳入构建，CTest 10/10 通过，ReClip offscreen 冷启动保持运行 8 秒。
- [x] Sphinx 未安装：它仅用于 ECM 文档生成，当前 `BUILD_QCH=OFF` 且应用运行/构建不使用文档目标，因此不作为本项目运行时依赖。
- [x] Android JNI 结果协议改为结构化 JSON（`path/bytes/format/backend`）并补充统一错误码；取消改为等待嵌入式 yt-dlp/FFmpeg worker 收尾后发送终态，arm64-v8a AAR/FFmpegKit Debug APK、Java 编译和 Gradle 二次打包通过。
- [x] Android arm64 协议测试 APK 已生成：`.build/android-arm64-protocol/android-build/build/outputs/apk/debug/android-build-debug.apk`，包名 `com.reclip.videodownloader.protocol`；真机安装被小米设备端 USB 确认拦截，因此本轮未把协议变更算入真机功能回归。
- [x] 2026-09-13 将当前 arm64 完整运行时 APK `.build/android-arm64-current-dev/android-build/ReClipApp.apk` 通过 ADB 覆盖安装到 Xiaomi `24094RAD4C`（`com.reclip.videodownloader.dev`），安装返回 `Success`；启动后 `MainActivity` 位于前台，进程保持运行，最近日志未发现崩溃或 native/linker 错误。
- [x] 收敛桌面和 Kirigami 两套设置页：仅保留桌面下载目录以及 Android/iOS 保存/导出位置；输出格式和清晰度继续在新建下载页选择，语言、主题和策略控件不再在设置页暴露。后端默认值和旧配置键保留以兼容已有数据。
- [x] 为 Android 移除 `Main.qml` 中传给设置页的残留 `tools` 属性绑定；该绑定会在设置页加载时触发 QML `Cannot assign to non-existent property "tools"` 并导致引擎返回 `-1`。
- [x] 使用较短构建目录 `.build/a64dev` 重新生成设置页精简后的 arm64 完整运行时 Debug APK，规避旧目录触发的 Windows Gradle 路径长度限制；APK 位于 `.build/a64dev/android-build/build/outputs/apk/debug/android-build-debug.apk`，已通过 ADB 覆盖安装到 Xiaomi `24094RAD4C` 的 `com.reclip.videodownloader.dev`，安装返回 `Success`。显式启动返回 `Status: ok`，`MainActivity` 位于前台，进程保持运行，最近日志未发现 QML、native 或 linker 错误。
- [x] 2026-09-13 按新的移动端设计新增顶部左侧圆形菜单按钮和左侧设置抽屉，移除 `MobileBottomBar.qml` 及其 Kirigami 窄桌面 footer；Windows CTest 10/10 通过，Android arm64 APK 重新打包并覆盖安装成功。
- [x] 2026-09-13 通过 Xiaomi `24094RAD4C` 真机截图复核移动端壳层：修正 `MobileHeader.qml` 中汉堡图标相对圆形按钮左偏的问题，并移除 `MobileSettingsDrawer.qml` 的外边框，避免抽屉边缘出现白线；修复后重新构建、安装并验证主界面/设置抽屉显示正常，Android 进程日志未发现 QML、native 或 linker 错误。
- [x] 2026-09-13 根据后续真机截图反馈移除 `MobileHeader.qml` 菜单按钮和 `MobileSettingsDrawer.qml` 关闭按钮的圆形边框；主页菜单与设置页 X 按钮均已复测为无白边，Android APK 已重新覆盖安装。
- [x] 2026-09-13 再次根据真机截图移除 `MobileHeader.qml` 根容器边框，清除菜单按钮所在顶部父窗口的矩形白边；重新安装后的主页和设置抽屉截图均已确认边框消失。
- [x] 2026-09-13 收敛移动端文件导出设置：隐藏具体 URI/路径，移除清除和打开目录操作，仅保留“设置保存位置”按钮；目录选择成功后显示“保存位置已设置”弹窗，并修正窄抽屉文案换行与按钮宽度。iOS 固定保存位置同样不再显示内部路径。
- [x] 2026-09-13 移除 Video Downloader 应用品牌图标：删除 Linux/macOS 平台图标资源及打包引用，去掉桌面侧栏的品牌下载图标；下载、设置、打开、分享等功能操作图标继续保留。更新的 Windows 便携包位于 `.artifacts/windows/ReClip-Release-ytdlp-sdk-no-brand-icon`，包内唯一 `.exe` 为 `ReClip.exe`，未发现 `.ico`、`.icns` 或 `.svg` 应用图标资源。
- [x] 2026-09-13 将桌面下载目录设置内联合并到下载工作台：移除 Qt Quick Controls 2 和 Kirigami 桌面页面栈中的独立设置页及桌面侧栏设置入口，工作台直接提供“保存位置”卡片；Android/iOS 和窄桌面继续保留左侧抽屉，用于系统保存位置选择或固定位置说明。
- [x] 2026-09-13 完成本轮合并后的回归：Windows Kirigami Release 构建通过，CTest 10/10 通过；Android arm64 Debug APK 重新生成并成功覆盖安装到 Xiaomi `24094RAD4C`，主界面和设置抽屉截图确认正常；当前 Windows 便携包为 `.artifacts/windows/ReClip-Release-ytdlp-sdk-workbench-settings`，包内唯一 `.exe` 为 `ReClip.exe`，无 `.ico`、`.icns` 或 `.svg` 应用图标资源。
- [x] 2026-09-13 按确认的桌面 UI 示例图收敛工作台视觉：桌面输入卡片改为紧凑布局，移除宽桌面巨型拖放区和编号装饰；保存位置、媒体预览、活动栏和侧栏统一为浅色轻量信息层级，桌面下载逻辑保持不变。Windows Kirigami CTest 10/10、Android APK 安装和截图回归通过；当前 Windows 便携包为 `.artifacts/windows/ReClip-Release-ytdlp-sdk-ui-v2`，包内唯一 `.exe` 为 `ReClip.exe`。
- [x] 2026-09-13 将确认的 Android UI 示例落地：移动端顶部显示当前工作区标题，主页面采用欢迎文案、无编号紧凑输入卡、媒体预览占位和不暴露 URI/路径的保存位置卡；左侧抽屉改为工作台/队列导航并保留引擎状态，底部切换栏继续移除。Android arm64 Debug APK 已安装到实机，主界面、队列页和抽屉截图回归通过，最近日志未发现 QML、native 或 linker 错误。
- [x] 2026-09-13 完成功能自测：Windows Kirigami CTest 10/10、Python 适配器 5/5、进程后端兼容 CTest 6/6；Android Xiaomi `24094RAD4C` 真机完成冷启动就绪、菜单抽屉开关、工作台/队列切换、系统保存位置选择器、输入框/键盘、无效链接错误处理，以及本地 HTTP 夹具通过 `ACTION_VIEW` 进入内嵌 yt-dlp 解析、MP4 下载校验、FFmpegKit MP3 转码和导出校验，应用始终保持前台，未发现崩溃或 QML/native/linker 致命错误。真实授权站点、鉴权和复杂流媒体场景仍按验收清单保留为待测项。
- [ ] OS 级零子进程观察未通过：当前环境订阅 Windows 进程创建事件返回 `Access denied`。功能验证日志明确记录未启用该观测，不能把 Python 审计钩子当作完整替代。
- [ ] T3、完整 T4/T5，以及 Python 多格式下载、真实授权站点双流/鉴权、长任务压力和网络/磁盘异常完整矩阵继续保留待办。

实现和发布入口、证据路径及限制统一记录在 [yt-dlp 内嵌运行时说明](docs/yt-dlp-embedded.md)。

#### 验收清单

- [ ] 在没有系统 Python、yt-dlp、FFmpeg/FFprobe 的干净环境中，内嵌发布包可以启动、报告版本并完成声明支持的下载。
- [ ] 覆盖普通 HTTP(S)、独立音视频、MP3；HLS/DASH、YouTube JS 及用户授权的鉴权用例分别记录实际支持范围，不用单个本地 MP4 成功代替网站验收。
- [ ] 覆盖解析/下载/处理阶段取消、连接和读取超时、重试等待、断网、磁盘不足、中文及空格路径、重复文件名和队列重启恢复。
- [ ] 取消确认后不再写入输出或发出成功事件；终止信号不重复，旧任务回调不会污染新任务。
- [ ] 输出使用 SDK 探测/解码验证，适用时比对文件哈希；记录各阶段进度，未知长度任务不伪造完成度。
- [ ] 从冷启动到最终文件完成观测子进程创建，覆盖所有声称零子进程的测试路径；发现辅助命令则修复或下调对应能力声明。
- [ ] SDK 开/关、严格/兼容模式均有回归；运行时缺失、ABI 不匹配和 JS 不可用时提供明确错误，不静默切换。
- [ ] 长任务及重复任务后检查内存增长、句柄/线程、退出等待、临时文件和敏感日志；实测记录包体积、冷启动和取消耗时。
- [ ] 依赖来源、版本、哈希、许可证、构建/更新说明完整；Android 与桌面的验证结果分别记录。

#### 参考资料

- [yt-dlp 官方 Python 嵌入接口与 hooks 示例](https://github.com/yt-dlp/yt-dlp#embedding-yt-dlp)
- [CPython 嵌入 C/C++ 应用](https://docs.python.org/3/extending/embedding.html)
- [CPython 隔离初始化配置](https://docs.python.org/3/c-api/init_config.html#isolated-configuration)
- [当前 Android AAR 上游的进程内架构和更新限制](https://github.com/ffmpegkit-maintained/yt-dlp-android#architecture)
- [yt-dlp EJS 与 JavaScript 引擎要求](https://github.com/yt-dlp/yt-dlp/wiki/EJS)
- [yt-dlp QuickJS provider 的子进程实现](https://github.com/yt-dlp/yt-dlp/blob/master/yt_dlp/extractor/youtube/jsc/_builtin/quickjs.py)

上游资料以 2026-09-12 本轮调查为依据；依赖版本、provider 接口与支持矩阵需在实际实施和升级时重新核验。

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
