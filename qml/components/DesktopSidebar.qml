import QtQuick
import QtQuick.Controls
import QtQuick.Layouts

Rectangle {
    id: root

    property string currentPage: "new"
    property bool toolsReady: true
    property string productName: "Video Downloader"
    signal navigate(string page)

    Layout.preferredWidth: Theme.sidebarWidth
    Layout.fillHeight: true
    color: Theme.sidebarBackground
    border.width: 1
    border.color: Theme.border

    ColumnLayout {
        anchors.fill: parent
        anchors.margins: 12
        spacing: 6

        RowLayout {
            Layout.fillWidth: true
            Layout.bottomMargin: 16
            spacing: 10

            Rectangle {
                Layout.preferredWidth: 36
                Layout.preferredHeight: 36
                radius: Theme.radiusControl
                color: Theme.accent

                Text {
                    anchors.centerIn: parent
                    text: "↓"
                    color: Theme.accentText
                    font.family: Theme.fontFamily
                    font.pixelSize: 20
                    font.weight: Font.Bold
                }
            }

            ColumnLayout {
                Layout.fillWidth: true
                spacing: 0

                Label {
                    text: root.productName
                    color: Theme.text
                    font.family: Theme.fontFamily
                    font.pixelSize: 15
                    font.weight: Font.DemiBold
                }

                Label {
                    text: "媒体下载工作台"
                    color: Theme.subtle
                    font.family: Theme.fontFamily
                    font.pixelSize: 11
                }
            }
        }

        NavigationItem {
            Layout.fillWidth: true
            text: "新建下载"
            iconText: "+"
            selected: root.currentPage === "new"
            onClicked: root.navigate("new")
        }

        NavigationItem {
            Layout.fillWidth: true
            text: "下载队列"
            iconText: "≡"
            selected: root.currentPage === "queue"
            onClicked: root.navigate("queue")
        }

        NavigationItem {
            Layout.fillWidth: true
            text: "设置"
            iconText: "settings"
            selected: root.currentPage === "settings"
            onClicked: root.navigate("settings")
        }

        Item { Layout.fillHeight: true }

        Rectangle {
            Layout.fillWidth: true
            implicitHeight: 1
            color: Theme.border
        }

        Button {
            Layout.fillWidth: true
            implicitHeight: 52
            leftPadding: 11
            rightPadding: 11
            onClicked: root.navigate("settings")

            contentItem: RowLayout {
                spacing: 9

                Rectangle {
                    Layout.preferredWidth: 8
                    Layout.preferredHeight: 8
                    radius: 4
                color: root.toolsReady ? Theme.signal : Theme.danger
                }

                ColumnLayout {
                    Layout.fillWidth: true
                    spacing: 1

                    Label {
                        text: "工具状态"
                        color: Theme.muted
                        font.family: Theme.fontFamily
                        font.pixelSize: 11
                    }

                    Label {
                        text: root.toolsReady ? "yt-dlp / FFmpeg 已就绪" : "需要检查工具"
                        color: root.toolsReady ? Theme.signal : Theme.warningText
                        font.family: Theme.fontFamily
                        font.pixelSize: 10
                        elide: Text.ElideRight
                    }
                }
            }

            background: Rectangle {
                color: parent.hovered ? Theme.surface : Theme.surfaceAlt
                radius: Theme.radiusPanel
                border.width: 1
                border.color: Theme.border
            }
        }

        Label {
            Layout.fillWidth: true
            text: "Video Downloader  ·  0.1"
            color: Theme.subtle
            font.family: Theme.monoFamily
            font.pixelSize: 10
            topPadding: 8
        }
    }
}
