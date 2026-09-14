import QtQuick
import QtQuick.Controls
import QtQuick.Layouts

Rectangle {
    id: root

    property var queue: null
    property bool compact: false
    readonly property int taskCount: root.queue ? root.queue.tasks.length : 0
    readonly property bool hasTasks: root.taskCount > 0
    readonly property bool hasStartableTasks: {
        if (!root.queue) {
            return false
        }
        for (var index = 0; index < root.queue.tasks.length; ++index) {
            var state = root.queue.tasks[index].state
            if (state === "queued" || state === "interrupted") {
                return true
            }
        }
        return false
    }
    readonly property bool hasCompletedTasks: {
        if (!root.queue) {
            return false
        }
        for (var index = 0; index < root.queue.tasks.length; ++index) {
            if (root.queue.tasks[index].state === "completed") {
                return true
            }
        }
        return false
    }
    readonly property string summaryText: {
        if (!root.hasTasks) {
            return "队列为空"
        }
        var active = 0
        var waiting = 0
        var completed = 0
        var failed = 0
        for (var index = 0; index < root.queue.tasks.length; ++index) {
            var state = root.queue.tasks[index].state
            if (state === "downloading") {
                active += 1
            } else if (state === "queued" || state === "waiting" || state === "interrupted") {
                waiting += 1
            } else if (state === "completed") {
                completed += 1
            } else {
                failed += 1
            }
        }
        var parts = []
        if (active > 0) parts.push(active + " 个进行中")
        if (waiting > 0) parts.push(waiting + " 个等待中")
        if (completed > 0) parts.push(completed + " 个已完成")
        if (failed > 0) parts.push(failed + " 个未完成")
        return parts.join("  ·  ")
    }
    signal openQueue()

    Layout.preferredWidth: 312
    Layout.preferredHeight: implicitHeight
    Layout.maximumHeight: 16777215
    Layout.fillHeight: false
    Layout.alignment: Qt.AlignTop
    implicitHeight: root.hasTasks
                    ? Math.min(620, 104 + Math.min(root.taskCount, 4) * 96
                               + (root.hasStartableTasks ? 52 : 0))
                    : 176
    color: Theme.surface
    radius: Theme.radiusPanel
    border.width: 1
    border.color: Theme.border

    ColumnLayout {
        anchors.fill: parent
        anchors.margins: root.compact ? 16 : 20
        spacing: 14

        RowLayout {
            Layout.fillWidth: true

            ColumnLayout {
                Layout.fillWidth: true
                spacing: 2

                Label {
                    text: "下载队列"
                    color: Theme.text
                    font.family: Theme.fontFamily
                    font.pixelSize: root.compact ? 17 : 22
                    font.weight: Font.DemiBold
                }

                Label {
                    text: root.summaryText
                    color: Theme.muted
                    font.family: Theme.fontFamily
                    font.pixelSize: root.compact ? 11 : 13
                    elide: Text.ElideRight
                }
            }

            AppButton {
                visible: root.hasCompletedTasks
                text: "清理已完成"
                variant: "ghost"
                compact: true
                onClicked: root.queue.clearCompleted()
            }
        }

        ListView {
            id: taskList
            visible: root.hasTasks
            Layout.fillWidth: true
            Layout.fillHeight: root.hasTasks
            clip: true
            spacing: 10
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
        }

        Item {
            visible: !root.hasTasks
            Layout.fillWidth: true
            Layout.preferredHeight: 92

            Column {
                anchors.centerIn: parent
                spacing: 3

                Label {
                    anchors.horizontalCenter: parent.horizontalCenter
                    text: "队列为空"
                    color: Theme.muted
                    font.family: Theme.fontFamily
                    font.pixelSize: 13
                    font.weight: Font.DemiBold
                }

                Label {
                    anchors.horizontalCenter: parent.horizontalCenter
                    text: "解析链接后会出现在这里"
                    color: Theme.subtle
                    font.family: Theme.fontFamily
                    font.pixelSize: 11
                }
            }
        }

        AppButton {
            Layout.fillWidth: true
            visible: root.hasStartableTasks && !root.queue.running
            text: "开始全部"
            iconName: "play"
            variant: "primary"
            onClicked: root.queue.startAll()
        }
    }
}
