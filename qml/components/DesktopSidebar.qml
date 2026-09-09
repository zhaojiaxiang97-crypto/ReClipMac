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
    border.width: 0

    Rectangle {
        anchors.top: parent.top
        anchors.right: parent.right
        anchors.bottom: parent.bottom
        width: 1
        color: Theme.border
    }

    ColumnLayout {
        anchors.fill: parent
        anchors.margins: 16
        spacing: 8

        RowLayout {
            Layout.fillWidth: true
            Layout.bottomMargin: 18
            spacing: 10

            Rectangle {
                Layout.preferredWidth: 38
                Layout.preferredHeight: 38
                radius: Theme.radiusControl
                color: Theme.accent

                Text {
                    anchors.centerIn: parent
                    text: "↓"
                    color: Theme.accentText
                    font.family: Theme.fontFamily
                    font.pixelSize: 21
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
                    font.pixelSize: 16
                    font.weight: Font.DemiBold
                }

                Label {
                    text: "本地媒体工作台"
                    color: Theme.subtle
                    font.family: Theme.fontFamily
                    font.pixelSize: 11
                }
            }
        }

        Label {
            text: "工作区"
            color: Theme.subtle
            font.family: Theme.fontFamily
            font.pixelSize: 10
            font.weight: Font.DemiBold
            font.letterSpacing: 1.1
            Layout.topMargin: 2
            Layout.bottomMargin: 2
        }

        NavigationItem {
            Layout.fillWidth: true
            text: "下载工作台"
            iconText: "+"
            selected: root.currentPage === "new"
            onClicked: root.navigate("new")
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
            implicitHeight: 58
            leftPadding: 12
            rightPadding: 12
            onClicked: root.navigate("settings")

            contentItem: RowLayout {
                spacing: 10

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
                        text: "下载引擎"
                        color: Theme.muted
                        font.family: Theme.fontFamily
                        font.pixelSize: 11
                    }

                    Label {
                        text: root.toolsReady ? "工具已就绪" : "需要检查工具"
                        color: root.toolsReady ? Theme.signal : Theme.warningText
                        font.family: Theme.fontFamily
                        font.pixelSize: 10
                        elide: Text.ElideRight
                    }
                }
            }

            background: Rectangle {
                color: parent.hovered ? Theme.selectionSurface : Theme.surfaceAlt
                radius: Theme.radiusControl
                border.width: 1
                border.color: Theme.border
            }
        }

        Label {
            Layout.fillWidth: true
            text: "LOCAL MEDIA  ·  0.1"
            color: Theme.subtle
            font.family: Theme.monoFamily
            font.pixelSize: 10
            topPadding: 8
        }
    }
}
