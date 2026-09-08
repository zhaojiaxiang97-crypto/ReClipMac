import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import org.kde.kirigami as Kirigami
import ReClip

Kirigami.ScrollablePage {
    id: root

    property var queue: null
    property bool compact: width < 700

    signal openNew()

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

            ColumnLayout {
                Layout.fillWidth: true
                visible: !root.compact
                spacing: 2

                Kirigami.Heading {
                    text: "下载队列"
                    color: Theme.text
                    font.family: Theme.fontFamily
                    font.pixelSize: root.compact ? 28 : 24
                    font.weight: Font.DemiBold
                }

                Label {
                    text: root.queue ? root.queue.statusText : "队列为空"
                    color: Theme.muted
                    font.family: Theme.fontFamily
                    font.pixelSize: 13
                }
            }

            Kirigami.ActionToolBar {
                Layout.alignment: Qt.AlignTop
                actions: [
                    Kirigami.Action {
                        text: root.compact ? "全部开始" : "开始全部"
                        icon.name: "media-playback-start"
                        visible: root.queue && root.queue.tasks.length > 0
                        enabled: root.queue && !root.queue.running
                        onTriggered: root.queue.startAll()
                    },
                    Kirigami.Action {
                        text: "清空已完成"
                        icon.name: "edit-clear-history"
                        visible: root.queue && root.queue.tasks.length > 0
                        onTriggered: root.queue.clearCompleted()
                    }
                ]
            }
        }

        Kirigami.InlineMessage {
            Layout.fillWidth: true
            visible: root.queue && root.queue.running
            type: Kirigami.MessageType.Positive
            text: "队列正在按顺序处理\n新的任务会等待当前下载完成。"
        }

        ColumnLayout {
            visible: root.queue && root.queue.tasks.length > 0
            Layout.fillWidth: true
            spacing: Kirigami.Units.largeSpacing

            Repeater {
                model: root.queue ? root.queue.tasks : []

                delegate: Kirigami.Card {
                    required property var modelData
                    Layout.fillWidth: true

                    contentItem: DownloadRow {
                        width: parent ? parent.width : 0
                        compact: root.compact
                        task: modelData
                        onCancelClicked: function (taskId) { root.queue.cancelTask(taskId) }
                        onRetryClicked: function (taskId) { root.queue.retryTask(taskId) }
                        onOpenClicked: function (taskId) { root.queue.openTask(taskId) }
                        onShareClicked: function (taskId) { root.queue.shareTask(taskId) }
                        onRemoveClicked: function (taskId) { root.queue.removeTask(taskId) }
                    }
                }
            }
        }

        Kirigami.PlaceholderMessage {
            visible: !root.queue || root.queue.tasks.length === 0
            Layout.fillWidth: true
            Layout.topMargin: Kirigami.Units.gridUnit * 2
            Layout.bottomMargin: Kirigami.Units.gridUnit * 2
            icon.name: "folder-download"
            text: "还没有下载任务"
            explanation: "粘贴一个公开媒体链接，确认格式后开始下载。"
            helpfulAction: Kirigami.Action {
                text: "新建下载"
                icon.name: "list-add"
                onTriggered: root.openNew()
            }
        }

        Label {
            Layout.fillWidth: true
            text: "任务会保留在这里，直到你删除它们。"
            color: Theme.subtle
            font.family: Theme.fontFamily
            font.pixelSize: 11
            horizontalAlignment: Text.AlignHCenter
            bottomPadding: Kirigami.Units.smallSpacing
        }
    }
}
