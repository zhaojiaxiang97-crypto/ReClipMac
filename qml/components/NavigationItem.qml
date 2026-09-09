import QtQuick
import QtQuick.Controls

Button {
    id: root

    property bool selected: false
    property string iconText: ""

    implicitHeight: 42
    leftPadding: 11
    rightPadding: 11
    topPadding: 0
    bottomPadding: 0

    contentItem: Row {
        spacing: 12
        anchors.verticalCenter: parent.verticalCenter

        IconGlyph {
            visible: root.iconText === "settings"
            name: "settings"
            color: root.selected ? Theme.accent : Theme.muted
            size: 20
            anchors.verticalCenter: parent.verticalCenter
        }

        Text {
            visible: root.iconText !== "settings"
            text: root.iconText
            color: root.selected ? Theme.accent : Theme.muted
            font.family: Theme.fontFamily
            font.pixelSize: 17
            font.weight: Font.Medium
            anchors.verticalCenter: parent.verticalCenter
        }

        Text {
            text: root.text
            color: root.selected ? Theme.accent : Theme.muted
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
    }
}
