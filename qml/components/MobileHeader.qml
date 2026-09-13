import QtQuick
import QtQuick.Controls
import QtQuick.Layouts

Rectangle {
    id: root

    signal menuClicked()
    property string title: ""

    Layout.fillWidth: true
    Layout.preferredHeight: 64
    implicitHeight: 64
    color: Theme.background
    border.width: 0

    Button {
        id: menuButton

        anchors.left: parent.left
        anchors.leftMargin: 16
        anchors.verticalCenter: parent.verticalCenter
        width: 44
        height: 44
        padding: 0
        text: "打开设置"
        onClicked: root.menuClicked()

        contentItem: Item {
            anchors.fill: parent

            Column {
                anchors.centerIn: parent
                spacing: 4

                Repeater {
                    model: 3

                    delegate: Rectangle {
                        required property int index
                        width: 20
                        height: 2
                        radius: 1
                        color: menuButton.down ? Theme.accent : Theme.text
                    }
                }
            }
        }

        background: Rectangle {
            radius: width / 2
            color: menuButton.down ? Theme.violetSurface
                                    : (menuButton.hovered ? Theme.surfaceRaised : Theme.surfaceAlt)
            border.width: 0
        }

        ToolTip.visible: hovered
        ToolTip.text: text
        ToolTip.delay: 600
    }

    Label {
        visible: root.title.length > 0
        anchors.centerIn: parent
        text: root.title
        color: Theme.text
        font.family: Theme.fontFamily
        font.pixelSize: 16
        font.weight: Font.DemiBold
    }
}
