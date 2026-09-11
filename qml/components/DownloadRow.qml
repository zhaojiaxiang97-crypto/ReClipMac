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

    implicitHeight: rowColumn.implicitHeight + (compact ? 20 : 28)

    Dialog {
        id: removeDialog
        modal: true
        title: "删除下载任务"
        width: Math.min(420, Math.max(280, root.width - 32))

        contentItem: ColumnLayout {
            spacing: 8

            Label {
                Layout.fillWidth: true
                text: "确定删除“%1”吗？".arg(root.taskTitle)
                color: Theme.text
                font.family: Theme.fontFamily
                font.pixelSize: 15
                font.weight: Font.DemiBold
                wrapMode: Text.Wrap
            }

            Label {
                Layout.fillWidth: true
                text: "任务记录和已生成的本地文件都会被移除。"
                color: Theme.muted
                font.family: Theme.fontFamily
                font.pixelSize: 12
                wrapMode: Text.Wrap
            }
        }

        footer: RowLayout {
            width: parent ? parent.width : 0
            spacing: 8

            Item { Layout.fillWidth: true }

            AppButton {
                text: "取消"
                variant: "ghost"
                compact: true
                onClicked: removeDialog.reject()
            }

            AppButton {
                text: "删除"
                iconName: "trash"
                variant: "danger"
                compact: true
                onClicked: removeDialog.accept()
            }
        }

        onAccepted: root.removeClicked(root.taskId)
    }

    Rectangle {
        anchors.fill: parent
        radius: Theme.radiusPanel
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

                IconGlyph {
                    anchors.centerIn: parent
                    name: root.taskIconName
                    color: root.taskColor
                    size: compact ? 16 : 18
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
                    text: (task.format || "MP4") + "  ·  " + root.taskStatus
                    color: Theme.muted
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
        }

        SignalTrace {
            visible: root.taskState === "downloading"
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
                    color: root.taskState === "failed" || root.taskState === "interrupted" ? Theme.danger : Theme.muted
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
                text: "删除"
                iconName: "trash"
                iconOnly: root.compact
                variant: "ghost"
                compact: true
                onClicked: removeDialog.open()
            }
        }

        Label {
            visible: (root.taskState === "failed" || root.taskState === "interrupted") && root.taskError
            Layout.fillWidth: true
            text: root.taskError || "下载未完成"
            color: Theme.danger
            font.family: Theme.fontFamily
            font.pixelSize: 12
            wrapMode: Text.Wrap
        }
    }
}
