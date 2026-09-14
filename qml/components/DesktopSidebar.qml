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
        anchors.margins: 24
        spacing: 12

        ColumnLayout {
            Layout.fillWidth: true
            Layout.bottomMargin: 34
            spacing: 0

            Label {
                text: root.productName
                color: Theme.text
                font.family: Theme.fontFamily
                font.pixelSize: 20
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

        NavigationItem {
            Layout.fillWidth: true
            text: "设置"
            iconName: "settings"
            selected: root.currentPage === "settings"
            onClicked: root.navigate("settings")
        }

        Item { Layout.fillHeight: true }

        Rectangle {
            Layout.fillWidth: true
            implicitHeight: 58
            radius: Theme.radiusControl
            color: Theme.surfaceAlt
            border.width: 1
            border.color: Theme.border

            RowLayout {
                anchors.fill: parent
                anchors.leftMargin: 12
                anchors.rightMargin: 12
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
