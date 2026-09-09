import QtQuick
import QtQuick.Controls
import "../vendor/QuickMaterial" as Material

ComboBox {
    id: root

    implicitHeight: Material.Metrics.field - 12
    leftPadding: Material.Metrics.pad.field
    rightPadding: Material.Metrics.pad.field + 24
    font.family: Theme.fontFamily
    font.pixelSize: 13

    contentItem: Text {
        leftPadding: root.leftPadding
        rightPadding: root.rightPadding
        text: root.displayText
        color: Theme.text
        font: root.font
        verticalAlignment: Text.AlignVCenter
        elide: Text.ElideRight
    }

    indicator: Text {
        x: root.width - width - Material.Metrics.pad.field
        anchors.verticalCenter: parent.verticalCenter
        text: "\u2304"
        color: root.activeFocus ? Theme.primaryBlue : Theme.muted
        font.family: Theme.fontFamily
        font.pixelSize: 22
    }

    background: Rectangle {
        radius: Material.Corner.small
        color: Theme.surface
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
    }

    delegate: ItemDelegate {
        required property int index
        width: root.width
        height: Math.max(40, Material.Metrics.menuItem - 8)
        highlighted: root.highlightedIndex === index

        contentItem: Text {
            text: root.textAt(index)
            color: Theme.text
            font: root.font
            verticalAlignment: Text.AlignVCenter
            elide: Text.ElideRight
        }

        background: Rectangle {
            radius: Material.Corner.extraSmall
            color: parent.highlighted ? Theme.primaryBlueSoft
                   : (parent.hovered ? Theme.surfaceAlt : "transparent")
        }
    }

    popup: Popup {
        y: root.height + 6
        width: root.width
        padding: 6

        contentItem: ListView {
            clip: true
            implicitHeight: contentHeight
            model: root.popup.visible ? root.delegateModel : null
            currentIndex: root.highlightedIndex
            ScrollIndicator.vertical: ScrollIndicator { }
        }

        background: Rectangle {
            radius: Material.Corner.medium
            color: Theme.surface
            border.width: 1
            border.color: Theme.border
        }
    }
}
