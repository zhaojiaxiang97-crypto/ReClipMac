import QtQuick
import QtQuick.Controls
import QtQuick.Layouts

Item {
    id: root

    property var task: ({})
    property bool compact: false

    signal cancelClicked(string taskId)
    signal retryClicked(string taskId)
    signal openClicked(string taskId)
    signal removeClicked(string taskId)

    readonly property string taskId: task && task.id ? task.id : ""
    readonly property string taskState: task && task.state ? task.state : "queued"
    readonly property string taskTitle: task && task.title ? task.title : (task && task.sourceUrl ? task.sourceUrl : "未命名任务")
    readonly property color taskColor: Theme.stateColor(taskState)

    implicitHeight: rowColumn.implicitHeight + (compact ? 20 : 28)

    Rectangle {
        anchors.fill: parent
        radius: Theme.radiusControl
        color: root.taskState === "downloading" ? Theme.surface : Theme.background
        border.width: 1
        border.color: root.taskState === "downloading"
                      ? Qt.rgba(root.taskColor.r, root.taskColor.g, root.taskColor.b, 0.52)
                      : Theme.border
    }

    ColumnLayout {
        id: rowColumn
        anchors.fill: parent
        anchors.margins: compact ? 10 : 14
        spacing: compact ? 8 : 10

        RowLayout {
            Layout.fillWidth: true
            spacing: 10

            Rectangle {
                Layout.preferredWidth: compact ? 24 : 30
                Layout.preferredHeight: compact ? 24 : 30
                radius: width / 2
                color: Theme.stateSurface(root.taskState)

                Text {
                    anchors.centerIn: parent
                    text: root.taskState === "completed" ? "✓" : (root.taskState === "failed" ? "!" : "•")
                    color: root.taskColor
                    font.family: Theme.fontFamily
                    font.pixelSize: compact ? 13 : 15
                    font.weight: Font.Bold
                }
            }

            ColumnLayout {
                Layout.fillWidth: true
                spacing: 3

                Label {
                    Layout.fillWidth: true
                    text: root.taskTitle
                    color: Theme.text
                    font.family: Theme.fontFamily
                    font.pixelSize: compact ? 13 : 14
                    font.weight: Font.DemiBold
                    elide: Text.ElideRight
                }

                Label {
                    Layout.fillWidth: true
                    text: (task.format || "MP4") + "  ·  " + (task.statusText || "等待下载")
                    color: Theme.muted
                    font.family: Theme.fontFamily
                    font.pixelSize: compact ? 11 : 12
                    elide: Text.ElideRight
                }
            }

            StatusPill {
                visible: !root.compact
                state: root.taskState
                label: task.statusText || "等待下载"
                compact: true
            }
        }

        SignalTrace {
            Layout.fillWidth: true
            progress: task.progress || 0
            state: root.taskState
            indeterminate: root.taskState === "queued" || root.taskState === "waiting"
            showMarker: root.taskState !== "queued" && root.taskState !== "waiting"
        }

        RowLayout {
            Layout.fillWidth: true
            spacing: 10

            Label {
                Layout.fillWidth: true
                text: {
                    var details = []
                    if (task.progress !== undefined && root.taskState === "downloading") {
                        details.push(Math.round(task.progress * 100) + "%")
                    }
                    if (task.speed) {
                        details.push(task.speed)
                    }
                    if (task.eta) {
                        details.push("剩余 " + task.eta)
                    }
                    if (root.taskState === "completed" && task.outputPath) {
                        details.push("已保存")
                    }
                    return details.join("  ·  ")
                }
                color: root.taskState === "failed" ? Theme.coral : Theme.muted
                font.family: Theme.monoFamily
                font.pixelSize: compact ? 11 : 12
                elide: Text.ElideMiddle
            }

            AppButton {
                visible: task.canCancel === true
                text: root.taskState === "downloading" ? "取消" : "取消等待"
                variant: "ghost"
                compact: true
                onClicked: root.cancelClicked(root.taskId)
            }

            AppButton {
                visible: task.canRetry === true
                text: "重试"
                variant: "secondary"
                compact: true
                onClicked: root.retryClicked(root.taskId)
            }

            AppButton {
                visible: root.taskState === "completed"
                text: compact ? "打开" : "打开文件"
                iconText: "↗"
                variant: "secondary"
                compact: true
                onClicked: root.openClicked(root.taskId)
            }

            AppButton {
                visible: !compact
                text: "删除"
                variant: "ghost"
                compact: true
                onClicked: root.removeClicked(root.taskId)
            }
        }

        Label {
            visible: root.taskState === "failed" && task.errorMessage
            Layout.fillWidth: true
            text: task.errorMessage || "下载未完成"
            color: Theme.coral
            font.family: Theme.fontFamily
            font.pixelSize: 12
            wrapMode: Text.Wrap
        }
    }
}
