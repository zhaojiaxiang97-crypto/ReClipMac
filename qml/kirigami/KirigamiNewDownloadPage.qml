import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import org.kde.kirigami as Kirigami
import ReClip

Kirigami.ScrollablePage {
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
        if (values.length > 0 && values[0].length > 0 && inspector) {
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

    background: Rectangle {
        color: Theme.background
    }

    ColumnLayout {
        id: content
        width: Math.max(root.width - (root.compact ? 32 : Theme.pageGutter * 2), 0)
        x: root.compact ? 16 : Theme.pageGutter
        y: root.compact ? 16 : Theme.pageTop
        spacing: root.compact ? Kirigami.Units.largeSpacing : Theme.pageSpacing

        RowLayout {
            Layout.fillWidth: true
            visible: !root.compact

            ColumnLayout {
                Layout.fillWidth: true
                spacing: 2

                Kirigami.Heading {
                    text: "新建下载"
                    color: Theme.text
                    font.family: Theme.fontFamily
                    font.pixelSize: root.compact ? 28 : 24
                    font.weight: Font.DemiBold
                }

                Label {
                    text: "粘贴链接，确认媒体信息后选择输出格式"
                    color: Theme.muted
                    font.family: Theme.fontFamily
                    font.pixelSize: 13
                }
            }

            Kirigami.ActionToolBar {
                Layout.alignment: Qt.AlignTop
                actions: [
                    Kirigami.Action {
                        text: "查看队列"
                        icon.name: "view-list-details"
                        onTriggered: root.openQueue()
                    }
                ]
            }
        }

        Kirigami.Card {
            id: captureCard
            Layout.fillWidth: true
            actions: [
                Kirigami.Action {
                    text: "从剪贴板粘贴"
                    icon.name: "edit-paste"
                    enabled: !capture.busy
                    onTriggered: capture.pasteRequested()
                }
            ]

            contentItem: LinkCapture {
                id: capture
                width: parent ? parent.width : 0
                compact: root.compact
                busy: root.inspector && root.inspector.inspecting

                onParseRequested: root.startInspection()
                onPasteRequested: {
                    capture.text = root.controller ? root.controller.clipboardText() : ""
                    if (capture.text.length > 0) {
                        root.startInspection()
                    }
                }
                onUrlsDropped: function (urls) {
                    capture.text = urls.join("\n")
                    root.startInspection()
                }
            }
        }

        Kirigami.InlineMessage {
            Layout.fillWidth: true
            visible: root.tools && !root.tools.ready && !root.tools.checking
            type: Kirigami.MessageType.Warning
            text: "下载工具还没有准备好\nVideo Downloader 需要 yt-dlp 和 FFmpeg 才能解析和处理媒体。"
            actions: [
                Kirigami.Action {
                    text: "打开工具诊断"
                    icon.name: "tools-wizard"
                    onTriggered: root.openTools()
                }
            ]
        }

        RowLayout {
            visible: root.inspector && root.inspector.inspecting
            Layout.fillWidth: true
            spacing: Kirigami.Units.smallSpacing

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

        Kirigami.InlineMessage {
            Layout.fillWidth: true
            visible: root.inspector && root.inspector.state === "error"
            type: Kirigami.MessageType.Error
            text: "无法读取这个链接\n" + (root.inspector ? root.inspector.errorMessage : "")
            actions: [
                Kirigami.Action {
                    text: root.tools && !root.tools.ready ? "打开工具诊断" : "重新解析"
                    icon.name: root.tools && !root.tools.ready ? "tools-wizard" : "view-refresh"
                    onTriggered: {
                        if (root.tools && !root.tools.ready) {
                            root.openTools()
                        } else {
                            root.startInspection()
                        }
                    }
                }
            ]
        }

        Kirigami.Card {
            Layout.fillWidth: true
            visible: root.inspector && root.inspector.hasResult

            contentItem: MediaPreview {
                width: parent ? parent.width : 0
                inspector: root.inspector
                settings: root.settings
                compact: root.compact
                onDownloadRequested: function (format) {
                    root.downloads.startDownload(root.inspector.sourceUrl, root.inspector.selectedFormatId, format)
                }
                onQueueRequested: function (format) {
                    root.queue.addTask(root.inspector.sourceUrl, root.inspector.selectedFormatId, format)
                    if (root.compact) {
                        root.openQueue()
                    }
                }
            }
        }

        Kirigami.Card {
            Layout.fillWidth: true
            visible: root.downloads && root.downloads.state !== "idle"

            contentItem: DownloadStatusPanel {
                width: parent ? parent.width : 0
                downloads: root.downloads
                compact: root.compact
            }
        }

        ColumnLayout {
            visible: root.compact && root.queue && root.queue.tasks.length > 0
            Layout.fillWidth: true
            spacing: Kirigami.Units.smallSpacing

            RowLayout {
                Layout.fillWidth: true

                Kirigami.Heading {
                    text: "最近任务"
                    color: Theme.text
                    font.family: Theme.fontFamily
                }

                Item { Layout.fillWidth: true }

                Kirigami.ActionToolBar {
                    actions: [
                        Kirigami.Action {
                            text: "查看全部"
                            icon.name: "view-list-details"
                            onTriggered: root.openQueue()
                        }
                    ]
                }
            }

            Repeater {
                model: root.queue ? Math.min(root.queue.tasks.length, 2) : 0

                delegate: Kirigami.Card {
                    required property int index
                    Layout.fillWidth: true

                    contentItem: DownloadRow {
                        width: parent ? parent.width : 0
                        compact: true
                        task: root.queue.tasks[index]
                        onCancelClicked: function (taskId) { root.queue.cancelTask(taskId) }
                        onRetryClicked: function (taskId) { root.queue.retryTask(taskId) }
                        onOpenClicked: function (taskId) { root.queue.openTask(taskId) }
                        onRemoveClicked: function (taskId) { root.queue.removeTask(taskId) }
                    }
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
            bottomPadding: Kirigami.Units.smallSpacing
        }
    }
}
