import QtQuick
import QtQuick.Controls
import QtQuick.Layouts

Item {
    id: root

    property var controller: null
    property var settings: null
    property var tools: null
    property var inspector: null
    property var downloads: null
    property var queue: null
    property bool compact: width < 700
    property string initialUrl: ""

    signal openQueue()
    signal openTools()

    function startInspection() {
        var values = capture.text.trim().split(/[\s,]+/)
        if (values.length > 0 && values[0].length > 0) {
            inspector.inspect(values[0])
        }
    }

    function acceptExternalUrl(url) {
        var value = (url || "").trim()
        if (value.length === 0) {
            return
        }
        capture.text = value
        startInspection()
    }

    onInitialUrlChanged: acceptExternalUrl(initialUrl)

    ScrollView {
        id: scroll
        anchors.fill: parent
        clip: true
        contentWidth: Math.max(availableWidth || 0, 0)

        ColumnLayout {
            id: content
            width: Math.max((scroll.availableWidth || 0) - (root.compact ? 32 : Theme.pageGutter * 2), 0)
            x: root.compact ? 16 : Theme.pageGutter
            y: root.compact ? 16 : Theme.pageTop
            spacing: root.compact ? 16 : Theme.pageSpacing

            RowLayout {
                Layout.fillWidth: true
                visible: !root.compact

                ColumnLayout {
                    Layout.fillWidth: true
                    spacing: 4

                    Label {
                        text: "新建下载"
                        color: Theme.text
                        font.family: Theme.fontFamily
                        font.pixelSize: root.compact ? 28 : 24
                        font.weight: Font.DemiBold
                    }

                    Label {
                        text: root.compact ? "粘贴链接，马上开始" : "粘贴链接，确认媒体信息后选择输出格式"
                        color: Theme.muted
                        font.family: Theme.fontFamily
                        font.pixelSize: root.compact ? 13 : 14
                    }
                }

                AppButton {
                    visible: !root.compact
                    text: "查看队列"
                    iconText: "≡"
                    variant: "ghost"
                    onClicked: root.openQueue()
                }
            }

            LinkCapture {
                id: capture
                Layout.fillWidth: true
                busy: inspector && inspector.inspecting

                onParseRequested: root.startInspection()
                onPasteRequested: {
                    capture.text = controller ? controller.clipboardText() : ""
                    if (capture.text.length > 0) {
                        root.startInspection()
                    }
                }
                onUrlsDropped: function (urls) {
                    capture.text = urls.join("\n")
                    root.startInspection()
                }
            }

            InlineNotice {
                Layout.fillWidth: true
                visible: tools && !tools.ready && !tools.checking
                tone: "warning"
                title: "下载工具还没有准备好"
                body: "Video Downloader 需要 yt-dlp 和 FFmpeg 才能解析和处理媒体。"
                actionText: "打开工具诊断"
                onActionTriggered: root.openTools()
            }

            RowLayout {
                visible: inspector && inspector.inspecting
                Layout.fillWidth: true
                spacing: 10

                SignalTrace {
                    Layout.fillWidth: true
                    indeterminate: true
                    state: "inspecting"
                }

                Label {
                    text: "正在读取媒体信息"
                    color: Theme.muted
                    font.family: Theme.fontFamily
                    font.pixelSize: 12
                }
            }

            InlineNotice {
                Layout.fillWidth: true
                visible: inspector && inspector.state === "error"
                tone: "danger"
                title: "无法读取这个链接"
                body: inspector ? inspector.errorMessage : ""
                actionText: tools && !tools.ready ? "打开工具诊断" : "重新解析"
                onActionTriggered: {
                    if (tools && !tools.ready) {
                        root.openTools()
                    } else {
                        root.startInspection()
                    }
                }
            }

            MediaPreview {
                Layout.fillWidth: true
                visible: inspector && inspector.hasResult
                inspector: root.inspector
                settings: root.settings
                compact: root.compact
                onDownloadRequested: function (format) {
                    if (Qt.platform.os === "ios") {
                        queue.addTask(inspector.sourceUrl, inspector.selectedFormatId, format)
                        queue.startAll()
                        root.openQueue()
                    } else {
                        downloads.startDownload(inspector.sourceUrl, inspector.selectedFormatId, format)
                    }
                }
                onQueueRequested: function (format) {
                    queue.addTask(inspector.sourceUrl, inspector.selectedFormatId, format)
                    if (root.compact) {
                        root.openQueue()
                    }
                }
            }

            DownloadStatusPanel {
                Layout.fillWidth: true
                downloads: root.downloads
                compact: root.compact
            }

            ColumnLayout {
                visible: root.compact && queue && queue.tasks.length > 0
                Layout.fillWidth: true
                spacing: 10

                RowLayout {
                    Layout.fillWidth: true

                    Label {
                        text: "最近任务"
                        color: Theme.text
                        font.family: Theme.fontFamily
                        font.pixelSize: 17
                        font.weight: Font.DemiBold
                    }

                    Item { Layout.fillWidth: true }

                    AppButton {
                        text: "查看全部"
                        variant: "ghost"
                        compact: true
                        onClicked: root.openQueue()
                    }
                }

                Repeater {
                    model: queue ? Math.min(queue.tasks.length, 2) : 0

                    delegate: DownloadRow {
                        required property int index
                        width: content.width
                        compact: true
                        task: queue.tasks[index]
                        onCancelClicked: function (taskId) { queue.cancelTask(taskId) }
                        onRetryClicked: function (taskId) { queue.retryTask(taskId) }
                        onOpenClicked: function (taskId) { queue.openTask(taskId) }
                        onRemoveClicked: function (taskId) { queue.removeTask(taskId) }
                    }
                }
            }

            Label {
                Layout.fillWidth: true
                text: "仅处理你有权保存的非 DRM 内容。"
                color: Theme.subtle
                font.family: Theme.fontFamily
                font.pixelSize: 11
                horizontalAlignment: Text.AlignHCenter
                wrapMode: Text.Wrap
                bottomPadding: 12
            }
        }
    }
}
