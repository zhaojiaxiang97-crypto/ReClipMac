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
    signal shareClicked(string taskId)
    signal removeClicked(string taskId)

    readonly property string taskId: task && task.id ? task.id : ""
    readonly property string taskState: task && task.state ? task.state : "queued"
    readonly property string taskTitle: task && task.title ? task.title : (task && task.sourceUrl ? task.sourceUrl : "未命名任务")
    readonly property string taskStatus: {
        var value = task && task.statusText ? task.statusText.trim() : ""
        if (/^\?+$/.test(value)) {
            if (root.taskState === "completed") return "下载完成"
            if (root.taskState === "failed") return "下载失败"
            if (root.taskState === "cancelled") return "已取消"
            if (root.taskState === "interrupted") return "应用关闭时中断，可重试"
            if (root.taskState === "downloading") return "下载中"
            if (root.taskState === "waiting") return "等待前一项完成"
            return "等待下载"
        }
        return value || "等待下载"
    }
    readonly property string taskError: {
        var value = task && task.errorMessage ? task.errorMessage.trim() : ""
        if (/^\?+$/.test(value)) {
            return root.taskState === "interrupted"
                    ? "应用关闭时任务尚未完成，请点击重试"
                    : "上次下载失败，请检查媒体链接和网络连接后重试"
        }
        return value
    }
    readonly property string taskDetails: {
        var details = []
        if (task.progress !== undefined && root.taskState === "downloading") {
            details.push(Math.round(task.progress * 100) + "%")
        }
        if (root.taskState === "downloading" && task.speed) {
            details.push(task.speed)
        }
        var eta = (task.eta || "").trim()
        if (root.taskState === "downloading" && eta) {
            var unknownEta = eta.toUpperCase() === "NA" || eta.toUpperCase() === "N/A"
            details.push(unknownEta ? "预计时间计算中" : "剩余 " + eta)
        }
        if (root.taskState === "completed" && task.outputPath) {
            details.push("已保存")
        }
        return details.join("  ·  ")
    }
    readonly property string taskIconName: {
        if (root.taskState === "completed") return "check"
        if (root.taskState === "failed") return "error"
        if (root.taskState === "interrupted") return "refresh"
        if (root.taskState === "cancelled") return "clear"
        if (root.taskState === "downloading") return "loading"
        if (root.taskState === "queued" || root.taskState === "waiting") return "queue"
        return "info"
    }
    readonly property color taskColor: Theme.stateColor(taskState)

    implicitHeight: Math.max(compact ? 78 : 92,
                             rowColumn.implicitHeight + (compact ? 24 : 32))

    AppDialog {
        id: removeDialog
        heading: "删除下载任务"
        iconName: "trash"
        tone: "danger"
        message: "确定删除“%1”吗？".arg(root.taskTitle)
        detail: "任务记录和已生成的本地文件都会被移除。"
        cancelText: "取消"
        confirmText: "删除"
        onConfirmed: root.removeClicked(root.taskId)
    }

    Rectangle {
        anchors.fill: parent
        radius: Theme.radiusPanel
        color: root.taskState === "downloading" ? Theme.surface : Theme.surfaceAlt
        border.width: 1
        border.color: root.taskState === "downloading"
                      ? Qt.rgba(root.taskColor.r, root.taskColor.g, root.taskColor.b, 0.52)
                      : Theme.border
    }

    ColumnLayout {
        id: rowColumn
        anchors.fill: parent
        anchors.margins: compact ? 12 : 16
        spacing: compact ? 6 : 10

        RowLayout {
            Layout.fillWidth: true
            spacing: compact ? 10 : 12

            Rectangle {
                Layout.preferredWidth: compact ? 32 : 36
                Layout.preferredHeight: compact ? 32 : 36
                radius: width / 2
                color: Theme.stateSurface(root.taskState)

                IconGlyph {
                    anchors.centerIn: parent
                    name: root.taskIconName
                    color: root.taskColor
                    size: compact ? 18 : 20
                }
            }

            ColumnLayout {
                Layout.fillWidth: true
                Layout.alignment: Qt.AlignTop
                spacing: 3

                Label {
                    Layout.fillWidth: true
                    text: root.taskTitle
                    color: Theme.text
                    font.family: Theme.fontFamily
                    font.pixelSize: compact ? 14 : 15
                    font.weight: Font.DemiBold
                    elide: Text.ElideRight
                }

                Label {
                    Layout.fillWidth: true
                    text: (task.format || "MP4") + "  ·  " + root.taskStatus
                    color: Theme.muted
                    font.family: Theme.fontFamily
                    font.pixelSize: compact ? 11 : 12
                    elide: Text.ElideRight
                }
                SignalTrace {
                    visible: root.taskState === "downloading"
                    Layout.fillWidth: true
                    Layout.preferredHeight: compact ? 5 : 6
                    progress: task.progress || 0
                    state: root.taskState
                    indeterminate: false
                    showMarker: false
                }

                Label {
                    visible: root.taskDetails.length > 0
                    Layout.fillWidth: true
                    text: root.taskDetails
                    color: root.taskState === "failed" || root.taskState === "interrupted"
                           ? Theme.danger : Theme.muted
                    font.family: Theme.monoFamily
                    font.pixelSize: compact ? 11 : 12
                    elide: Text.ElideMiddle
                }

                Label {
                    visible: (root.taskState === "failed" || root.taskState === "interrupted")
                             && root.taskError.length > 0
                    Layout.fillWidth: true
                    text: root.taskError
                    color: Theme.danger
                    font.family: Theme.fontFamily
                    font.pixelSize: compact ? 11 : 12
                    elide: Text.ElideRight
                }
            }

            StatusPill {
                visible: !root.compact
                state: root.taskState
                label: root.taskStatus
                compact: true
            }

            RowLayout {
                Layout.alignment: Qt.AlignTop
                spacing: 6

                AppButton {
                    visible: task.canCancel === true
                    text: root.compact ? "" : (root.taskState === "downloading" ? "取消" : "取消等待")
                    iconName: "clear"
                    iconOnly: root.compact
                    variant: "ghost"
                    compact: true
                    Accessible.name: "取消下载"
                    onClicked: root.cancelClicked(root.taskId)
                }

                AppButton {
                    visible: task.canRetry === true
                    text: root.compact ? "" : "重试"
                    iconName: "refresh"
                    iconOnly: root.compact
                    variant: "secondary"
                    compact: true
                    Accessible.name: "重试下载"
                    onClicked: root.retryClicked(root.taskId)
                }

                AppButton {
                    visible: root.taskState === "completed"
                    text: "打开"
                    iconName: "open"
                    variant: "secondary"
                    compact: true
                    onClicked: root.openClicked(root.taskId)
                }

                AppButton {
                    visible: root.taskState === "completed" && Qt.platform.os === "android"
                    text: "分享"
                    iconName: "share"
                    variant: "secondary"
                    compact: true
                    onClicked: root.shareClicked(root.taskId)
                }

                AppButton {
                    enabled: root.taskId.length > 0
                    text: root.compact ? "" : "删除"
                    iconName: "trash"
                    iconOnly: root.compact
                    variant: "ghost"
                    compact: true
                    Accessible.name: "删除下载任务"
                    onClicked: removeDialog.open()
                }
            }
        }
    }
}
