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
    signal openQueue()

    Layout.preferredWidth: 312
    Layout.preferredHeight: implicitHeight
    Layout.maximumHeight: root.queue && root.queue.running ? 16777215 : implicitHeight
    Layout.fillHeight: root.queue && root.queue.running
    Layout.alignment: Qt.AlignTop
    implicitHeight: root.hasTasks
                    ? Math.min(480, 104 + root.taskCount * 132 + (root.hasStartableTasks ? 48 : 0))
                    : 174
    color: Theme.surface
    radius: Theme.radiusPanel
    border.width: 1
    border.color: Theme.border

    ColumnLayout {
        anchors.fill: parent
        anchors.margins: 16
        spacing: 10

        RowLayout {
            Layout.fillWidth: true

            ColumnLayout {
                Layout.fillWidth: true
                spacing: 2

                Label {
                    text: "传输队列"
                    color: Theme.text
                    font.family: Theme.fontFamily
                    font.pixelSize: 16
                    font.weight: Font.DemiBold
                }

                Label {
                    text: root.hasTasks ? "队列中有 %1 个任务".arg(root.taskCount) : "队列为空"
                    color: Theme.muted
                    font.family: Theme.fontFamily
                    font.pixelSize: 11
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

        SignalTrace {
            visible: root.hasTasks && activeState() === "downloading"
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
            visible: root.hasTasks
            text: "下载任务"
            color: Theme.muted
            font.family: Theme.fontFamily
            font.pixelSize: 11
            font.weight: Font.DemiBold
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
            Layout.preferredHeight: 64

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
            iconText: "▶"
            variant: "primary"
            onClicked: root.queue.startAll()
        }
    }
}
