import QtQuick
import QtQuick.Controls

Button {
    id: root

    property bool selected: false
    property string iconText: ""

    implicitHeight: 46
    leftPadding: 12
    rightPadding: 12
    topPadding: 0
    bottomPadding: 0

    contentItem: Row {
        spacing: 13
        anchors.verticalCenter: parent.verticalCenter

        IconGlyph {
            visible: root.iconText === "settings"
            name: "settings"
            color: root.selected ? Theme.text : Theme.muted
            size: 20
            anchors.verticalCenter: parent.verticalCenter
        }

        Text {
            visible: root.iconText !== "settings"
            text: root.iconText
            color: root.selected ? Theme.text : Theme.muted
            font.family: Theme.fontFamily
            font.pixelSize: 17
            font.weight: Font.Medium
            anchors.verticalCenter: parent.verticalCenter
        }

        Text {
            text: root.text
            color: root.selected ? Theme.text : Theme.muted
            font.family: Theme.fontFamily
            font.pixelSize: 13
            font.weight: root.selected ? Font.DemiBold : Font.Normal
            font.letterSpacing: 0.2
            anchors.verticalCenter: parent.verticalCenter
        }
    }

    background: Rectangle {
        radius: Theme.radiusSelection
        color: root.selected ? Theme.selectionSurface : (root.hovered ? Theme.surfaceAlt : "transparent")

        Rectangle {
            visible: root.selected
            width: 3
            height: 22
            anchors.left: parent.left
            anchors.leftMargin: 3
            anchors.verticalCenter: parent.verticalCenter
            radius: 2
            color: Theme.accent
        }
    }
}
