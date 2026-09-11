import QtQuick
import QtQuick.Controls
import QtQuick.Layouts

Item {
    id: root

    property var queue: null
    property bool compact: width < 700

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

                ColumnLayout {
                    Layout.fillWidth: true
                    spacing: 4

                    Label {
                        text: "下载队列"
                        color: Theme.text
                        font.family: Theme.fontFamily
                        font.pixelSize: root.compact ? 28 : 24
                        font.weight: Font.DemiBold
                    }

                    Label {
                        text: queue ? queue.statusText : "队列为空"
                        color: Theme.muted
                        font.family: Theme.fontFamily
                        font.pixelSize: 13
                    }
                }

                AppButton {
                    visible: queue && queue.tasks.length > 0
                    text: root.compact ? "全部开始" : "开始全部"
                    iconName: "play"
                    variant: "primary"
                    compact: root.compact
                    enabled: !queue.running
                    onClicked: queue.startAll()
                }

                AppButton {
                    visible: queue && queue.tasks.length > 0
                    text: "清空已完成"
                    variant: "ghost"
                    compact: true
                    onClicked: queue.clearCompleted()
                }
            }

            InlineNotice {
                Layout.fillWidth: true
                visible: queue && queue.running
                tone: "success"
                title: "队列正在按顺序处理"
                body: "新的任务会等待当前下载完成。"
            }

            ColumnLayout {
                visible: queue && queue.tasks.length > 0
                Layout.fillWidth: true
                spacing: 16

                Repeater {
                    model: queue ? queue.tasks : []

                    delegate: DownloadRow {
                        required property var modelData
                        Layout.fillWidth: true
                        compact: root.compact
                        task: modelData
                        onCancelClicked: function (taskId) { queue.cancelTask(taskId) }
                        onRetryClicked: function (taskId) { queue.retryTask(taskId) }
                        onOpenClicked: function (taskId) { queue.openTask(taskId) }
                        onShareClicked: function (taskId) { queue.shareTask(taskId) }
                        onRemoveClicked: function (taskId) { queue.removeTask(taskId) }
                    }
                }
            }

            ColumnLayout {
                visible: !queue || queue.tasks.length === 0
                Layout.fillWidth: true
                Layout.topMargin: 48
                Layout.bottomMargin: 48
                spacing: 12

                Text {
                    Layout.alignment: Qt.AlignHCenter
                    text: "○"
                    color: Theme.violet
                    font.family: Theme.fontFamily
                    font.pixelSize: 42
                    font.weight: Font.Light
                }

                Label {
                    Layout.fillWidth: true
                    text: "还没有下载任务"
                    color: Theme.text
                    font.family: Theme.fontFamily
                    font.pixelSize: 18
                    font.weight: Font.DemiBold
                    horizontalAlignment: Text.AlignHCenter
                }

                Label {
                    Layout.fillWidth: true
                    text: "粘贴一个公开媒体链接，确认格式后开始下载。"
                    color: Theme.muted
                    font.family: Theme.fontFamily
                    font.pixelSize: 13
                    horizontalAlignment: Text.AlignHCenter
                    wrapMode: Text.Wrap
                }
            }

            Label {
                Layout.fillWidth: true
                text: "任务会保留在这里，直到你删除它们。"
                color: Theme.subtle
                font.family: Theme.fontFamily
                font.pixelSize: 11
                horizontalAlignment: Text.AlignHCenter
                bottomPadding: 12
            }
        }
    }
}
