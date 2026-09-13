import QtQuick
import QtQuick.Controls

Button {
    id: root

    property bool selected: false
    property string iconName: "info"

    implicitHeight: 46
    leftPadding: 12
    rightPadding: 12
    topPadding: 0
    bottomPadding: 0

    contentItem: Row {
        spacing: 11
        anchors.verticalCenter: parent.verticalCenter

        IconGlyph {
            name: root.iconName
            color: root.selected ? Theme.accent : Theme.muted
            size: 18
            anchors.verticalCenter: parent.verticalCenter
        }

        Text {
            text: root.text
            color: root.selected ? Theme.accent : Theme.muted
            font.family: Theme.fontFamily
            font.pixelSize: 14
            font.weight: root.selected ? Font.DemiBold : Font.Normal
            font.letterSpacing: 0.2
            anchors.verticalCenter: parent.verticalCenter
        }
    }

    background: Rectangle {
        radius: Theme.radiusControl
        color: root.selected ? Theme.selectionSurface : (root.hovered ? Theme.surfaceAlt : "transparent")
    }
}
