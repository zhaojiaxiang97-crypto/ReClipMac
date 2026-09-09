import QtQuick
import QtQuick.Controls
import "../vendor/QuickMaterial" as Material

TextField {
    id: root

    implicitHeight: Material.Metrics.field - 12
    leftPadding: Material.Metrics.pad.field
    rightPadding: Material.Metrics.pad.field
    font.family: Theme.fontFamily
    font.pixelSize: 13
    color: Theme.text
    placeholderTextColor: Theme.subtle
    selectByMouse: true

    background: Rectangle {
        radius: Material.Corner.small
        color: root.readOnly ? Theme.surfaceAlt : Theme.surface
        border.width: root.activeFocus ? Material.Metrics.stroke.focus : Material.Metrics.stroke.thin
        border.color: root.activeFocus ? Theme.primaryBlue
                     : (root.hovered ? Theme.primaryBlueSoft : Theme.border)

        Rectangle {
            anchors.fill: parent
            radius: parent.radius
            color: Theme.primaryBlue
            opacity: root.activeFocus ? Material.States.focus
                   : (root.hovered ? Material.States.hover : 0)
        }

        Behavior on border.color {
            ColorAnimation { duration: 120 }
        }
    }
}
