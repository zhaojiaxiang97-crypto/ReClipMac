import QtQuick
import QtQuick.Controls
import QtQuick.Layouts

Rectangle {
    id: root

    property string tone: "warning"
    property string title: ""
    property string body: ""
    property string actionText: ""
    signal actionTriggered()

    implicitHeight: content.implicitHeight + 24
    radius: Theme.radiusControl
    color: tone === "danger" ? Theme.dangerSurface : (tone === "success" ? Theme.signalSurface : Theme.warningSurface)
    border.width: 1
    border.color: tone === "danger" ? Theme.dangerBorder : (tone === "success" ? Theme.successBorder : Theme.warningBorder)

    RowLayout {
        id: content
        anchors.fill: parent
        anchors.margins: 12
        spacing: 12

        Rectangle {
            Layout.preferredWidth: 28
            Layout.preferredHeight: 28
            radius: 14
            color: tone === "danger" ? Theme.coral : (tone === "success" ? Theme.signal : Theme.amber)

            Text {
                anchors.centerIn: parent
                text: tone === "danger" ? "!" : (tone === "success" ? "✓" : "i")
                color: "#FFFFFF"
                font.family: Theme.fontFamily
                font.pixelSize: 14
                font.weight: Font.Bold
            }
        }

        ColumnLayout {
            Layout.fillWidth: true
            spacing: 3

            Label {
                visible: root.title.length > 0
                text: root.title
                color: tone === "danger" ? Theme.coral : (tone === "success" ? Theme.signal : Theme.warningText)
                font.family: Theme.fontFamily
                font.pixelSize: 13
                font.weight: Font.DemiBold
            }

            Label {
                Layout.fillWidth: true
                text: root.body
                color: Theme.text
                font.family: Theme.fontFamily
                font.pixelSize: 13
                wrapMode: Text.Wrap
            }
        }

        AppButton {
            visible: root.actionText.length > 0
            text: root.actionText
            variant: "ghost"
            compact: true
            onClicked: root.actionTriggered()
        }
    }
}
