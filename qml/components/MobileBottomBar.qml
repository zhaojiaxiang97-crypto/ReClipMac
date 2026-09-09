import QtQuick
import QtQuick.Controls
import QtQuick.Layouts

Rectangle {
    id: root

    property string currentPage: "new"
    signal navigate(string page)

    Layout.fillWidth: true
    implicitHeight: 84
    color: Theme.surface
    border.color: Theme.border
    border.width: 1

    RowLayout {
        anchors.fill: parent
        anchors.leftMargin: 12
        anchors.rightMargin: 12
        anchors.topMargin: 8
        anchors.bottomMargin: 8
        spacing: 10

        NavItem {
            Layout.fillWidth: true
            Layout.preferredWidth: 1
            Layout.minimumWidth: 0
            text: "下载工作台"
            iconText: "download"
            selected: root.currentPage === "new"
            onClicked: root.navigate("new")
        }

        NavItem {
            Layout.fillWidth: true
            Layout.preferredWidth: 1
            Layout.minimumWidth: 0
            text: "设置"
            iconText: "settings"
            selected: root.currentPage === "settings"
            onClicked: root.navigate("settings")
        }
    }

    component NavItem: Button {
        id: item
        property bool selected: false
        property string iconText: ""
        implicitHeight: 64
        Layout.preferredWidth: 1
        Layout.minimumWidth: 0
        Layout.fillWidth: true
        topPadding: 6
        bottomPadding: 6

        contentItem: Column {
                spacing: 4
            anchors.centerIn: parent

            IconGlyph {
                name: item.iconText
                color: item.selected ? Theme.accent : Theme.muted
                size: 22
                anchors.horizontalCenter: parent.horizontalCenter
            }

            Text {
                anchors.horizontalCenter: parent.horizontalCenter
                text: item.text
                color: item.selected ? Theme.accent : Theme.muted
                font.family: Theme.fontFamily
                font.pixelSize: 11
                font.weight: item.selected ? Font.Medium : Font.Normal
            }
        }

        background: Rectangle {
            anchors.fill: parent
            radius: Theme.radiusSelection
            color: item.selected ? Theme.selectionSurface : Theme.surfaceAlt
            border.width: 1
            border.color: item.selected ? Theme.accent : Theme.border
        }
    }
}
