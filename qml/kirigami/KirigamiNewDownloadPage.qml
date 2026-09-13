import QtQuick
import QtQuick.Controls
import QtQuick.Dialogs
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
    readonly property bool mobilePlatform: Qt.platform.os === "android" || Qt.platform.os === "ios"


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

    function openFolderDialog() {
        if (folderDialogLoader.item) {
            folderDialogLoader.item.open()
        }
    }

    onInitialUrlChanged: acceptExternalUrl(initialUrl)

    Loader {
        id: folderDialogLoader
        active: !root.mobilePlatform
        sourceComponent: Component {
            FolderDialog {
                title: "选择下载目录"
                onAccepted: {
                    if (root.settings) {
                        root.settings.downloadDirectory = selectedFolder.toLocalFile()
                    }
                }
            }
        }
    }

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
            spacing: 2

            Kirigami.Heading {
                text: "下载工作台"
                color: Theme.text
                font.family: Theme.fontFamily
                font.pixelSize: root.compact ? 28 : 30
                font.weight: Font.DemiBold
            }

            Label {
                text: "粘贴媒体链接，解析并下载视频或音频"
                color: Theme.muted
                font.family: Theme.fontFamily
                font.pixelSize: root.compact ? 13 : 15
            }
        }

        LinkCapture {
            Layout.fillWidth: true
            id: capture
            compact: root.compact
            workspaceMode: false
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

        Kirigami.Card {
            Layout.fillWidth: true
            Layout.maximumWidth: 860
            Layout.alignment: Qt.AlignLeft
            visible: !root.compact

            background: Rectangle {
                color: Theme.surface
                radius: Theme.radiusPanel
                border.width: 1
                border.color: Theme.border
            }

            contentItem: ColumnLayout {
                width: parent ? parent.width : 0
                spacing: Kirigami.Units.smallSpacing

                RowLayout {
                    Layout.fillWidth: true

                    ColumnLayout {
                        Layout.fillWidth: true
                        spacing: 2

                        Label {
                            text: "保存位置"
                            color: Theme.text
                            font.family: Theme.fontFamily
                            font.pixelSize: 16
                            font.weight: Font.DemiBold
                        }

                        Label {
                            text: "下载完成后会保存到此文件夹"
                            color: Theme.muted
                            font.family: Theme.fontFamily
                            font.pixelSize: 12
                        }
                    }

                    StatusPill {
                        state: root.settings && root.settings.downloadDirectoryValid ? "completed" : "failed"
                        label: root.settings ? root.settings.downloadDirectoryStatus : ""
                        compact: true
                    }
                }

                RowLayout {
                    Layout.fillWidth: true
                    spacing: Kirigami.Units.smallSpacing

                    AppTextField {
                        id: directoryField
                        Layout.fillWidth: true
                        text: root.settings ? root.settings.downloadDirectory : ""
                        selectByMouse: true
                        font.family: Theme.monoFamily
                        font.pixelSize: 13
                        placeholderText: "下载文件夹"
                    }

                    AppButton {
                        text: "选择目录"
                        iconName: "folder"
                        variant: "secondary"
                        compact: true
                        onClicked: root.openFolderDialog()
                    }

                    AppButton {
                        text: "保存"
                        iconName: "check"
                        variant: "primary"
                        compact: true
                        onClicked: {
                            if (root.settings) {
                                root.settings.downloadDirectory = directoryField.text
                            }
                        }
                    }
                }
            }
        }

        Kirigami.InlineMessage {
            Layout.fillWidth: true
            visible: root.tools && !root.tools.ready && !root.tools.checking
            type: Kirigami.MessageType.Warning
            text: "下载引擎还没有准备好\n下载运行时尚未完成初始化，请稍后重新解析。"
        }

        ColumnLayout {
            visible: root.inspector && root.inspector.inspecting
            Layout.fillWidth: true
            spacing: Kirigami.Units.smallSpacing / 2

            Label {
                Layout.fillWidth: true
                text: "正在读取媒体信息"
                color: Theme.muted
                font.family: Theme.fontFamily
                font.pixelSize: 12
            }

            SignalTrace {
                Layout.fillWidth: true
                Layout.preferredHeight: 8
                implicitHeight: 8
                indeterminate: true
                showMarker: false
                state: "inspecting"
            }
        }

        Kirigami.InlineMessage {
            Layout.fillWidth: true
            visible: root.inspector && root.inspector.state === "error"
            type: Kirigami.MessageType.Error
            text: "无法读取这个链接\n" + (root.inspector ? root.inspector.errorMessage : "")
            actions: [
                Kirigami.Action {
                    text: "重新解析"
                    icon.name: "view-refresh"
                    onTriggered: root.startInspection()
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
                root.queue.addTaskWithTitle(root.inspector.sourceUrl,
                                             root.inspector.selectedFormatId,
                                             format, root.inspector.title)
                root.queue.startAll()
            }
            onQueueRequested: function (format) {
                root.queue.addTaskWithTitle(root.inspector.sourceUrl,
                                             root.inspector.selectedFormatId,
                                             format, root.inspector.title)
            }
        }

        ActivityPanel {
            visible: root.inlineQueue
            Layout.fillWidth: true
            Layout.preferredWidth: 0
            Layout.minimumWidth: 0
            compact: root.compact
            queue: root.queue
        }

    }
}
