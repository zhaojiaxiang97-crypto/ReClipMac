import QtQuick
import QtQuick.Controls

Button {
    id: root

    property bool selected: false
    property string iconText: ""

    implicitHeight: 44
    leftPadding: 12
    rightPadding: 12
    topPadding: 0
    bottomPadding: 0

    contentItem: Row {
        spacing: 11
        anchors.verticalCenter: parent.verticalCenter

        Text {
            text: root.iconText
            color: root.selected ? "#FFFFFF" : "#AAB6CA"
            font.family: Theme.fontFamily
            font.pixelSize: 16
            font.weight: Font.DemiBold
            anchors.verticalCenter: parent.verticalCenter
        }

        Text {
            text: root.text
            color: root.selected ? "#FFFFFF" : "#AAB6CA"
            font.family: Theme.fontFamily
            font.pixelSize: 13
            font.weight: root.selected ? Font.DemiBold : Font.Normal
            anchors.verticalCenter: parent.verticalCenter
        }
    }

    background: Rectangle {
        radius: Theme.radiusControl
        color: root.selected ? Theme.violet : (root.hovered ? "#202D46" : "transparent")

        Rectangle {
            anchors.left: parent.left
            anchors.verticalCenter: parent.verticalCenter
            width: 3
            height: 22
            radius: 2
            color: Theme.signal
            visible: root.selected
        }
    }
}
