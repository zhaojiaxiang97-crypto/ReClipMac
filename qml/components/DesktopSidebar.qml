import QtQuick
import QtQuick.Controls
import QtQuick.Layouts

Rectangle {
    id: root

    property string currentPage: "new"
    property bool toolsReady: true
    property string productName: "ReClipQt"
    signal navigate(string page)

    Layout.preferredWidth: 224
    Layout.fillHeight: true
    color: Theme.ink

    ColumnLayout {
        anchors.fill: parent
        anchors.margins: 16
        spacing: 8

        RowLayout {
            Layout.fillWidth: true
            Layout.bottomMargin: 18
            spacing: 10

            Rectangle {
                Layout.preferredWidth: 34
                Layout.preferredHeight: 34
                radius: 10
                color: Theme.violet

                Text {
                    anchors.centerIn: parent
                    text: "⌁"
                    color: "#FFFFFF"
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
                    color: "#FFFFFF"
                    font.family: Theme.fontFamily
                    font.pixelSize: 16
                    font.weight: Font.Bold
                }

                Label {
                    text: "Signal Desk"
                    color: "#8090AA"
                    font.family: Theme.fontFamily
                    font.pixelSize: 10
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
            iconText: "⚙"
            selected: root.currentPage === "settings"
            onClicked: root.navigate("settings")
        }

        Item { Layout.fillHeight: true }

        Rectangle {
            Layout.fillWidth: true
            implicitHeight: 1
            color: "#27344D"
        }

        Button {
            Layout.fillWidth: true
            implicitHeight: 48
            leftPadding: 10
            rightPadding: 10
            onClicked: root.navigate("settings")

            contentItem: RowLayout {
                spacing: 9

                Rectangle {
                    Layout.preferredWidth: 8
                    Layout.preferredHeight: 8
                    radius: 4
                    color: root.toolsReady ? Theme.signal : Theme.coral
                }

                ColumnLayout {
                    Layout.fillWidth: true
                    spacing: 1

                    Label {
                        text: "工具状态"
                        color: "#AAB6CA"
                        font.family: Theme.fontFamily
                        font.pixelSize: 11
                    }

                    Label {
                        text: root.toolsReady ? "yt-dlp / FFmpeg 已就绪" : "需要检查工具"
                        color: root.toolsReady ? "#69D6C8" : "#F0B8A8"
                        font.family: Theme.fontFamily
                        font.pixelSize: 10
                        elide: Text.ElideRight
                    }
                }
            }

            background: Rectangle {
                color: parent.hovered ? "#202D46" : "transparent"
                radius: Theme.radiusControl
            }
        }

        Label {
            Layout.fillWidth: true
            text: "Qt / QML  ·  0.1"
            color: "#66758F"
            font.family: Theme.monoFamily
            font.pixelSize: 10
            topPadding: 8
        }
    }
}
