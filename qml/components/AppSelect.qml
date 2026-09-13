import QtQuick
import QtQuick.Controls

// A platform-neutral selector used by the download workbench. Qt's Basic
// ComboBox popup is intentionally replaced here because its native delegate
// does not follow the Graphite Rose/light desktop surface system.
ComboBox {
    id: root

    property bool compact: false
    property string compactText: ""
    property string emptyText: ""
    property int maxPopupHeight: 240

    readonly property string shownText: root.compact && root.compactText.length > 0
                                        ? root.compactText
                                        : (root.displayText.length > 0 ? root.displayText : root.emptyText)

    function itemText(itemIndex, itemData) {
        if (itemData !== undefined && itemData !== null) {
            if (typeof itemData === "string") {
                return itemData
            }
            if (itemData.label !== undefined) {
                return String(itemData.label)
            }
            if (itemData.text !== undefined) {
                return String(itemData.text)
            }
        }
        var value = root.textAt(itemIndex)
        return value === undefined || value === null ? "" : String(value)
    }

    implicitHeight: root.compact ? 46 : 40
    leftPadding: root.compact ? 14 : 13
    rightPadding: 40
    font.family: Theme.fontFamily
    font.pixelSize: 13

    contentItem: Text {
        anchors.fill: parent
        leftPadding: root.leftPadding
        rightPadding: root.rightPadding
        text: root.shownText
        color: root.enabled ? Theme.text : Theme.subtle
        font: root.font
        verticalAlignment: Text.AlignVCenter
        elide: Text.ElideRight
    }

    indicator: Item {
        width: 18
        height: 18
        x: root.width - width - 10
        y: (root.height - height) / 2

        Rectangle {
            x: 1
            y: 6
            width: 8
            height: 2
            radius: 1
            rotation: 45
            color: root.enabled ? Theme.muted : Theme.subtle
        }

        Rectangle {
            x: 7
            y: 6
            width: 8
            height: 2
            radius: 1
            rotation: -45
            color: root.enabled ? Theme.muted : Theme.subtle
        }
    }

    background: Rectangle {
        radius: Theme.radiusControl
        color: root.enabled ? Theme.surface : Theme.surfaceAlt
        border.width: root.visualFocus ? 2 : 1
        border.color: root.visualFocus ? Theme.accent : Theme.border
    }

    delegate: ItemDelegate {
        required property int index
        required property var modelData

        width: selectPopup.width - 12
        height: root.compact ? 48 : 44
        highlighted: root.highlightedIndex === index

        contentItem: Text {
            x: 12
            y: 0
            width: Math.max(0, parent.width - 52)
            height: parent.height
            text: root.itemText(index, modelData)
            color: Theme.text
            font: root.font
            verticalAlignment: Text.AlignVCenter
            elide: Text.ElideNone
            clip: true
        }

        IconGlyph {
            id: selectedMark
            anchors.right: parent.right
            anchors.rightMargin: 12
            anchors.verticalCenter: parent.verticalCenter
            visible: root.currentIndex === index
            z: 2
            name: "check"
            color: Theme.accent
            size: 17
        }

        background: Rectangle {
            radius: Theme.radiusSmall
            color: root.highlightedIndex === index
                   ? Theme.selectionSurface
                   : (parent.hovered ? Theme.surfaceAlt : "transparent")
        }
    }

    popup: Popup {
        id: selectPopup

        y: root.height + 6
        width: root.width + 24
        padding: 6
        implicitHeight: Math.min(selectList.contentHeight, root.maxPopupHeight) + padding * 2
        closePolicy: Popup.CloseOnEscape | Popup.CloseOnPressOutside | Popup.CloseOnReleaseOutside

        contentItem: ListView {
            id: selectList
            clip: true
            implicitHeight: Math.min(contentHeight, root.maxPopupHeight)
            model: root.popup.visible ? root.delegateModel : null
            currentIndex: root.highlightedIndex
            boundsBehavior: Flickable.StopAtBounds
            ScrollIndicator.vertical: ScrollIndicator { }
        }

        background: Rectangle {
            radius: Theme.radiusPanel
            color: Theme.surfaceAlt
            border.width: 1
            border.color: Theme.border
        }
    }
}
