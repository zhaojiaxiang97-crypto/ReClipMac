import QtQuick
import QtQuick.Controls
import QtQuick.Layouts

Item {
    id: root

    property var downloads: null
    property bool compact: false

    implicitHeight: panelColumn.implicitHeight + 32
    visible: downloads && downloads.state !== "idle"

    Rectangle {
        anchors.fill: parent
        radius: Theme.radiusPanel
        color: Theme.surface
        border.width: 1
        border.color: downloads && downloads.state === "failed" ? Theme.dangerBorder : Theme.border
    }

    ColumnLayout {
        id: panelColumn
        anchors.fill: parent
        anchors.margins: 16
        spacing: 12

        RowLayout {
            Layout.fillWidth: true

            ColumnLayout {
                Layout.fillWidth: true
                spacing: 3

                Label {
                    text: root.downloads ? root.downloads.statusText : ""
                    color: root.downloads ? Theme.stateColor(root.downloads.state) : Theme.text
                    font.family: Theme.fontFamily
                    font.pixelSize: 16
                    font.weight: Font.DemiBold
                }

                Label {
                    visible: root.downloads && root.downloads.outputPath.length > 0
                    text: root.downloads ? root.downloads.outputPath : ""
                    color: Theme.muted
                    font.family: Theme.monoFamily
                    font.pixelSize: 11
                    elide: Text.ElideMiddle
                    Layout.fillWidth: true
                }
            }

            Label {
                visible: root.downloads && root.downloads.state === "downloading"
                text: root.downloads ? Math.round(root.downloads.progress * 100) + "%" : ""
                color: Theme.text
                font.family: Theme.monoFamily
                font.pixelSize: 20
                font.weight: Font.DemiBold
            }
        }

        SignalTrace {
            Layout.fillWidth: true
            progress: root.downloads ? root.downloads.progress : 0
            state: root.downloads ? root.downloads.state : "idle"
            indeterminate: root.downloads && root.downloads.state === "preparing"
        }

        RowLayout {
            visible: root.downloads && root.downloads.state === "downloading"
            Layout.fillWidth: true
            spacing: 12

            Label {
                Layout.fillWidth: true
                Layout.minimumWidth: 0
                text: root.downloads && root.downloads.speed.length > 0 ? root.downloads.speed : ""
                color: Theme.muted
                font.family: Theme.monoFamily
                font.pixelSize: 12
                elide: Text.ElideRight
            }

            Label {
                Layout.minimumWidth: 0
                Layout.maximumWidth: compact ? 132 : 180
                text: root.downloads && root.downloads.eta.length > 0 ? "剩余 " + root.downloads.eta : ""
                color: Theme.muted
                font.family: Theme.monoFamily
                font.pixelSize: 12
                elide: Text.ElideRight
            }

            AppButton {
                Layout.alignment: Qt.AlignRight | Qt.AlignVCenter
                Layout.minimumWidth: compact ? 92 : 104
                Layout.preferredWidth: compact ? 92 : 104
                Layout.maximumWidth: compact ? 104 : 120
                text: "取消"
                variant: "ghost"
                compact: true
                onClicked: root.downloads.cancel()
            }
        }

        InlineNotice {
            Layout.fillWidth: true
            visible: root.downloads && root.downloads.errorMessage.length > 0
            tone: "danger"
            title: "下载未完成"
            body: root.downloads ? root.downloads.errorMessage : ""
        }

        RowLayout {
            Layout.fillWidth: true
            visible: root.downloads && (root.downloads.state === "completed"
                                        || root.downloads.state === "failed"
                                        || root.downloads.state === "cancelled")
            spacing: 8

            AppButton {
                visible: root.downloads && root.downloads.canRetry
                text: "重试"
                variant: "secondary"
                compact: true
                onClicked: root.downloads.retry()
            }

            AppButton {
                visible: root.downloads && root.downloads.state === "completed"
                text: "打开文件"
                iconName: "open"
                variant: "primary"
                compact: true
                onClicked: root.downloads.openOutput()
            }

            AppButton {
                visible: root.downloads && root.downloads.state === "completed" && Qt.platform.os === "android"
                text: "分享"
                iconName: "share"
                variant: "secondary"
                compact: true
                onClicked: root.downloads.shareOutput()
            }

            AppButton {
                text: "打开下载目录"
                iconName: "folder-open"
                variant: "ghost"
                compact: true
                onClicked: root.downloads.openDownloadDirectory()
            }
        }
    }
}
