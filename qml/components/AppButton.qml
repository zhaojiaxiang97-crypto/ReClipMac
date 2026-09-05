import QtQuick
import QtQuick.Controls

Button {
    id: root

    property string variant: "secondary"
    property string iconText: ""
    property bool compact: false

    implicitHeight: compact ? 34 : 40
    implicitWidth: Math.max(92, contentItem.implicitWidth + leftPadding + rightPadding)
    leftPadding: compact ? 12 : 16
    rightPadding: compact ? 12 : 16
    topPadding: 0
    bottomPadding: 0
    spacing: 8

    font.family: Theme.fontFamily
    font.pixelSize: compact ? 12 : 14
    font.weight: Font.DemiBold

    contentItem: Row {
        spacing: root.iconText.length > 0 ? 8 : 0
        anchors.centerIn: parent

        Text {
            visible: root.iconText.length > 0
            text: root.iconText
            color: root.contentColor
            font.family: Theme.fontFamily
            font.pixelSize: root.compact ? 14 : 16
            font.weight: Font.DemiBold
            anchors.verticalCenter: parent.verticalCenter
        }

        Text {
            text: root.text
            color: root.contentColor
            font: root.font
            anchors.verticalCenter: parent.verticalCenter
        }
    }

    readonly property color contentColor: {
        if (root.variant === "primary" || root.variant === "danger") {
            return "#FFFFFF"
        }
        return root.enabled ? Theme.text : Theme.subtle
    }

    background: Rectangle {
        radius: Theme.radiusControl
        color: {
            if (!root.enabled) {
                return Theme.surfaceAlt
            }
            if (root.variant === "primary") {
                return root.down ? Qt.darker(Theme.violet, 1.12) : (root.hovered ? Qt.lighter(Theme.violet, 1.08) : Theme.violet)
            }
            if (root.variant === "danger") {
                return root.down ? Qt.darker(Theme.coral, 1.12) : (root.hovered ? Qt.lighter(Theme.coral, 1.06) : Theme.coral)
            }
            if (root.variant === "ghost") {
                return root.down || root.hovered ? Theme.surfaceAlt : "transparent"
            }
            return root.down || root.hovered ? Theme.surfaceAlt : Theme.surface
        }
        border.width: root.variant === "primary" || root.variant === "danger" || root.variant === "ghost" ? 0 : 1
        border.color: Theme.border

        Rectangle {
            anchors.fill: parent
            anchors.margins: -2
            visible: root.visualFocus
            radius: parent.radius + 2
            color: "transparent"
            border.width: 2
            border.color: Theme.violet
        }
    }
}
