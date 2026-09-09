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
    property bool inlineQueue: false
    property bool compact: width < 700
    property string initialUrl: ""

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
        spacing: root.compact ? Kirigami.Units.largeSpacing : 20

        ColumnLayout {
            Layout.fillWidth: true
            visible: !root.compact
            spacing: 2

            Kirigami.Heading {
                text: "下载工作台"
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

        LinkCapture {
            Layout.fillWidth: true
            id: capture
            compact: root.compact
            workspaceMode: !root.inlineQueue
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

        MediaPreview {
            Layout.fillWidth: true
            visible: root.inspector && root.inspector.hasResult

            inspector: root.inspector
            settings: root.settings
            compact: root.compact
            onDownloadRequested: function (format) {
                root.queue.addTask(root.inspector.sourceUrl, root.inspector.selectedFormatId, format)
                root.queue.startAll()
            }
            onQueueRequested: function (format) {
                root.queue.addTask(root.inspector.sourceUrl, root.inspector.selectedFormatId, format)
            }
        }

        ActivityPanel {
            visible: root.inlineQueue
            Layout.fillWidth: true
            Layout.preferredWidth: 0
            Layout.minimumWidth: 0
            queue: root.queue
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
