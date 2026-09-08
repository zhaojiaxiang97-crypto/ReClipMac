import QtQuick
import QtQuick.Controls
import QtQuick.Layouts

Rectangle {
    id: root

    property var queue: null
    property bool compact: false
    signal openQueue()

    Layout.preferredWidth: 300
    Layout.fillHeight: true
    color: Theme.background
    border.width: 0

    Rectangle {
        anchors.left: parent.left
        anchors.top: parent.top
        anchors.bottom: parent.bottom
        width: 1
        color: Theme.border
    }

    ColumnLayout {
        anchors.fill: parent
        anchors.margins: 16
        spacing: 12

        RowLayout {
            Layout.fillWidth: true

            ColumnLayout {
                Layout.fillWidth: true
                spacing: 2

                Label {
                    text: "活动"
                    color: Theme.text
                    font.family: Theme.fontFamily
                    font.pixelSize: 16
                    font.weight: Font.DemiBold
                }

                Label {
                    text: root.queue ? root.queue.statusText : "队列为空"
                    color: Theme.muted
                    font.family: Theme.fontFamily
                    font.pixelSize: 11
                }
            }

            AppButton {
                text: "全部"
                variant: "ghost"
                compact: true
                onClicked: root.openQueue()
            }
        }

        SignalTrace {
            Layout.fillWidth: true
            progress: activeProgress()
            state: activeState()
            indeterminate: activeState() === "waiting" || activeState() === "queued"
                           || activeState() === "interrupted"
            showMarker: false

            function activeProgress() {
                if (!root.queue) {
                    return 0
                }
                for (var index = 0; index < root.queue.tasks.length; ++index) {
                    var task = root.queue.tasks[index]
                    if (task.state === "downloading") {
                        return task.progress || 0
                    }
                }
                return 0
            }

            function activeState() {
                if (!root.queue) {
                    return "idle"
                }
                for (var index = 0; index < root.queue.tasks.length; ++index) {
                    var task = root.queue.tasks[index]
                    if (task.state === "downloading" || task.state === "waiting"
                            || task.state === "queued" || task.state === "interrupted") {
                        return task.state
                    }
                }
                return "completed"
            }
        }

        Label {
            visible: root.queue && root.queue.tasks.length > 0
            text: "当前任务"
            color: Theme.muted
            font.family: Theme.fontFamily
            font.pixelSize: 11
            font.weight: Font.DemiBold
        }

        ListView {
            id: taskList
            Layout.fillWidth: true
            Layout.fillHeight: true
            clip: true
            spacing: 8
            model: root.queue ? root.queue.tasks : []

            delegate: DownloadRow {
                required property var modelData
                width: taskList.width
                compact: true
                task: modelData
                onCancelClicked: function (taskId) { root.queue.cancelTask(taskId) }
                onRetryClicked: function (taskId) { root.queue.retryTask(taskId) }
                onOpenClicked: function (taskId) { root.queue.openTask(taskId) }
                onRemoveClicked: function (taskId) { root.queue.removeTask(taskId) }
            }

            Label {
                anchors.centerIn: parent
                visible: taskList.count === 0
                text: "还没有任务\n粘贴链接后，它们会出现在这里"
                color: Theme.subtle
                font.family: Theme.fontFamily
                font.pixelSize: 12
                horizontalAlignment: Text.AlignHCenter
                lineHeight: 1.35
            }
        }

        AppButton {
            Layout.fillWidth: true
            visible: root.queue && root.queue.tasks.length > 0 && !root.queue.running
            text: "开始全部"
            iconText: "▶"
            variant: "primary"
            onClicked: root.queue.startAll()
        }
    }
}
