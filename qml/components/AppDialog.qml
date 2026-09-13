import QtQuick
import QtQuick.Controls
import QtQuick.Layouts

Dialog {
    id: root

    property string heading: ""
    property string message: ""
    property string detail: ""
    property string iconName: "info"
    property string tone: "info"
    property string confirmText: "确定"
    property string cancelText: "取消"
    property string confirmVariant: tone === "danger" ? "danger" : "primary"
    property bool showCancelButton: cancelText.length > 0

    readonly property color toneColor: tone === "danger" ? Theme.danger
                                      : (tone === "success" ? Theme.signal : Theme.accent)
    readonly property color toneSurface: tone === "danger" ? Theme.dangerSurface
                                        : (tone === "success" ? Theme.signalSurface : Theme.violetSurface)

    signal confirmed()
    signal cancelled()

    parent: Overlay.overlay
    anchors.centerIn: parent
    modal: true
    focus: true
    title: ""
    standardButtons: Dialog.NoButton
    closePolicy: Popup.CloseOnEscape
    width: Math.min(440, Math.max(280, (parent ? parent.width : 440) - 48))
    padding: 24

    Overlay.modal: Rectangle {
        color: Qt.rgba(0, 0, 0, Theme.darkMode ? 0.62 : 0.36)
    }

    background: Rectangle {
        radius: 24
        color: Theme.darkMode ? Theme.surfaceAlt : Theme.surface
        border.width: 1
        border.color: Theme.darkMode
                      ? Qt.rgba(Theme.text.r, Theme.text.g, Theme.text.b, 0.12)
                      : Theme.border
    }

    contentItem: ColumnLayout {
        spacing: 0
        implicitWidth: 320

        RowLayout {
            Layout.fillWidth: true
            spacing: 14

            Rectangle {
                Layout.preferredWidth: 48
                Layout.preferredHeight: 48
                radius: width / 2
                color: root.toneSurface

                IconGlyph {
                    anchors.centerIn: parent
                    name: root.iconName
                    color: root.toneColor
                    size: 24
                }
            }

            Label {
                Layout.fillWidth: true
                text: root.heading
                color: Theme.text
                font.family: Theme.fontFamily
                font.pixelSize: 20
                font.weight: Font.DemiBold
                wrapMode: Text.Wrap
            }
        }

        Item {
            Layout.fillWidth: true
            Layout.preferredHeight: root.message.length > 0 ? 22 : 0
        }

        Label {
            Layout.fillWidth: true
            visible: root.message.length > 0
            text: root.message
            color: Theme.text
            font.family: Theme.fontFamily
            font.pixelSize: 16
            font.weight: Font.Medium
            lineHeight: 1.12
            wrapMode: Text.Wrap
        }

        Item {
            Layout.fillWidth: true
            Layout.preferredHeight: root.detail.length > 0 ? 8 : 0
        }

        Label {
            Layout.fillWidth: true
            visible: root.detail.length > 0
            text: root.detail
            color: Theme.muted
            font.family: Theme.fontFamily
            font.pixelSize: 13
            lineHeight: 1.15
            wrapMode: Text.Wrap
        }

        Item {
            Layout.fillWidth: true
            Layout.preferredHeight: 24
        }

        RowLayout {
            Layout.fillWidth: true
            spacing: 12

            AppButton {
                visible: root.showCancelButton
                Layout.fillWidth: true
                Layout.minimumWidth: 0
                Layout.preferredHeight: Theme.touchTarget
                text: root.cancelText
                variant: "secondary"
                pill: true
                onClicked: root.reject()
            }

            AppButton {
                Layout.fillWidth: true
                Layout.minimumWidth: 0
                Layout.preferredHeight: Theme.touchTarget
                text: root.confirmText
                variant: root.confirmVariant
                iconName: root.tone === "danger" ? "trash" : ""
                pill: true
                onClicked: root.accept()
            }
        }
    }

    onAccepted: root.confirmed()
    onRejected: root.cancelled()
}
