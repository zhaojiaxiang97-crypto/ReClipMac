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
        anchors.margins: 20
        spacing: 10

        ColumnLayout {
            Layout.fillWidth: true
            Layout.bottomMargin: 28
            spacing: 0

            Label {
                text: root.productName
                color: Theme.text
                font.family: Theme.fontFamily
                font.pixelSize: 18
                font.weight: Font.DemiBold
            }

            Label {
                text: "本地媒体工作台"
                color: Theme.subtle
                font.family: Theme.fontFamily
                font.pixelSize: 12
            }
        }

        NavigationItem {
            Layout.fillWidth: true
            text: "下载工作台"
            iconName: "download"
            selected: root.currentPage === "new"
            onClicked: root.navigate("new")
        }

        Item { Layout.fillHeight: true }

        Rectangle {
            Layout.fillWidth: true
            implicitHeight: 44
            color: "transparent"
            border.width: 0

            RowLayout {
                anchors.fill: parent
                spacing: 9

                Rectangle {
                    Layout.preferredWidth: 7
                    Layout.preferredHeight: 7
                    radius: 3.5
                    color: root.toolsReady ? Theme.signal : Theme.danger
                }

                ColumnLayout {
                    Layout.fillWidth: true
                    spacing: 0
                    Label {
                        text: root.toolsReady ? "引擎状态：已就绪" : "引擎状态：未就绪"
                        color: root.toolsReady ? Theme.signal : Theme.warningText
                        font.family: Theme.fontFamily
                        font.pixelSize: 12
                        elide: Text.ElideRight
                    }
                }
            }

        }

    }
}
