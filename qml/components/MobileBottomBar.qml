import QtQuick
import QtQuick.Controls
import QtQuick.Layouts

Rectangle {
    id: root

    property string currentPage: "new"
    signal navigate(string page)

    Layout.fillWidth: true
    Layout.preferredHeight: 72
    color: Theme.surface
    border.color: Theme.border
    border.width: 1

    RowLayout {
        anchors.fill: parent
        anchors.leftMargin: 12
        anchors.rightMargin: 12
        spacing: 8

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
            iconText: "⚙"
            selected: root.currentPage === "settings"
            onClicked: root.navigate("settings")
        }
    }

    component NavItem: Button {
        id: item
        property bool selected: false
        property string iconText: ""
        implicitHeight: 58
        topPadding: 6
        bottomPadding: 5

        contentItem: Column {
            spacing: 3
            anchors.centerIn: parent

            Text {
                anchors.horizontalCenter: parent.horizontalCenter
                text: item.iconText
                color: item.selected ? Theme.violet : Theme.muted
                font.family: Theme.fontFamily
                font.pixelSize: 18
                font.weight: Font.DemiBold
            }

            Text {
                anchors.horizontalCenter: parent.horizontalCenter
                text: item.text
                color: item.selected ? Theme.violet : Theme.muted
                font.family: Theme.fontFamily
                font.pixelSize: 11
                font.weight: item.selected ? Font.DemiBold : Font.Normal
            }
        }

        background: Rectangle {
            radius: Theme.radiusControl
            color: item.selected ? Theme.violetSurface : (item.hovered ? Theme.surfaceAlt : "transparent")
        }
    }
}
