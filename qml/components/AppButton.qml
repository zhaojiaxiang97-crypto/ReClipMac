import QtQuick
import QtQuick.Controls

Button {
    id: root

    property string variant: "secondary"
    property string iconName: ""
    // Kept for compatibility with out-of-tree QML pages. New pages should
    // use iconName so the action is rendered as a real vector icon.
    property string iconText: ""
    property bool compact: false
    property bool iconOnly: false

    implicitHeight: compact ? 34 : 40
    implicitWidth: root.iconOnly ? (compact ? 34 : 40)
                                 : Math.max(88, contentItem.implicitWidth + leftPadding + rightPadding)
    leftPadding: root.iconOnly ? 0 : (compact ? 12 : 16)
    rightPadding: root.iconOnly ? 0 : (compact ? 12 : 16)
    topPadding: 0
    bottomPadding: 0
    spacing: 8

    font.family: Theme.fontFamily
    font.pixelSize: compact ? 12 : 14
    font.weight: Font.Medium
    font.letterSpacing: 0.1

    contentItem: Row {
        spacing: root.iconOnly ? 0 : (root.iconName.length > 0 || root.iconText.length > 0 ? 8 : 0)
        anchors.centerIn: parent

        IconGlyph {
            visible: root.iconName.length > 0
            name: root.iconName
            color: root.contentColor
            anchors.verticalCenter: parent.verticalCenter
            size: root.compact ? 16 : 18
        }

        Text {
            visible: !root.iconOnly && root.iconName.length === 0 && root.iconText.length > 0
            text: root.iconText
            color: root.contentColor
            font.family: Theme.fontFamily
            font.pixelSize: root.compact ? 14 : 15
            font.weight: Font.Medium
            anchors.verticalCenter: parent.verticalCenter
        }

        Text {
            visible: !root.iconOnly
            text: root.text
            color: root.contentColor
            font: root.font
            anchors.verticalCenter: parent.verticalCenter
        }
    }

    readonly property color contentColor: {
        if (root.variant === "primary") {
            return Theme.accentText
        }
        if (root.variant === "danger") {
            return "#FFFFFF"
        }
        return root.enabled ? Theme.text : Theme.subtle
    }

    background: Rectangle {
        radius: root.variant === "primary" ? Theme.radiusAction : Theme.radiusControl
        color: {
            if (!root.enabled) {
                return Theme.surfaceAlt
            }
            if (root.variant === "primary") {
                return root.down ? Qt.darker(Theme.accent, 1.08) : (root.hovered ? Theme.accentHover : Theme.accent)
            }
            if (root.variant === "danger") {
                return root.down ? Qt.darker(Theme.danger, 1.12) : (root.hovered ? Qt.lighter(Theme.danger, 1.06) : Theme.danger)
            }
            if (root.variant === "ghost") {
                return root.down || root.hovered ? Theme.surfaceAlt : "transparent"
            }
            return root.down || root.hovered ? Theme.violetSurface : Theme.surface
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
            border.color: Theme.accent
        }
    }

    ToolTip.visible: root.iconOnly && root.hovered
    ToolTip.text: root.text
    ToolTip.delay: 600
}
