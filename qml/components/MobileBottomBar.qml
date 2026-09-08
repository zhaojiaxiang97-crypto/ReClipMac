import QtQuick
import QtQuick.Controls
import QtQuick.Layouts

Rectangle {
    id: root

    property string currentPage: "new"
    signal navigate(string page)

    Layout.fillWidth: true
    Layout.preferredHeight: 92
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
            text: "新建"
            iconText: "+"
            selected: root.currentPage === "new"
            onClicked: root.navigate("new")
        }

        NavItem {
            Layout.fillWidth: true
            text: "队列"
            iconText: "≡"
            selected: root.currentPage === "queue"
            onClicked: root.navigate("queue")
        }

        NavItem {
            Layout.fillWidth: true
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
        implicitHeight: 72
        topPadding: 6
        bottomPadding: 6

        contentItem: Column {
                spacing: 4
            anchors.centerIn: parent

            IconGlyph {
                visible: item.iconText === "settings"
                name: "settings"
                color: item.selected ? Theme.text : Theme.muted
                size: 22
                anchors.horizontalCenter: parent.horizontalCenter
            }

            Text {
                visible: item.iconText !== "settings"
                anchors.horizontalCenter: parent.horizontalCenter
                text: item.iconText
                color: item.selected ? Theme.text : Theme.muted
                font.family: Theme.fontFamily
                font.pixelSize: 20
                font.weight: Font.Medium
            }

            Text {
                anchors.horizontalCenter: parent.horizontalCenter
                text: item.text
                color: item.selected ? Theme.text : Theme.muted
                font.family: Theme.fontFamily
                font.pixelSize: 11
                font.weight: item.selected ? Font.Medium : Font.Normal
            }
        }

        background: Rectangle {
            width: Math.min(item.width - 24, 190)
            height: 64
            anchors.centerIn: parent
            radius: Theme.radiusSelection
            color: item.selected ? Theme.selectionSurface : (item.hovered ? Theme.surfaceAlt : "transparent")
        }
    }
}
