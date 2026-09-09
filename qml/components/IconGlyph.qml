import QtQuick

Item {
    id: root

    property string name: ""
    property color color: Theme.text
    property real size: 22

    implicitWidth: root.size
    implicitHeight: root.size

    Text {
        anchors.centerIn: parent
        visible: root.name !== "settings" && root.name !== "download" && root.name !== "queue"
        text: root.name
        color: root.color
        font.family: Theme.fontFamily
        font.pixelSize: root.size
        font.weight: Font.Medium
        horizontalAlignment: Text.AlignHCenter
        verticalAlignment: Text.AlignVCenter
    }

    Item {
        anchors.fill: parent
        visible: root.name === "download"

        Rectangle {
            width: Math.max(2, root.size * 0.12)
            height: root.size * 0.46
            x: (parent.width - width) / 2
            y: root.size * 0.08
            radius: width / 2
            color: root.color
        }

        Rectangle {
            width: root.size * 0.38
            height: Math.max(2, root.size * 0.12)
            x: root.size * 0.32
            y: root.size * 0.45
            rotation: 45
            radius: height / 2
            color: root.color
        }

        Rectangle {
            width: root.size * 0.38
            height: Math.max(2, root.size * 0.12)
            x: root.size * 0.3
            y: root.size * 0.45
            rotation: -45
            radius: height / 2
            color: root.color
        }

        Rectangle {
            width: root.size * 0.68
            height: Math.max(2, root.size * 0.12)
            x: (parent.width - width) / 2
            y: root.size * 0.86
            radius: height / 2
            color: root.color
        }
    }

    Item {
        anchors.fill: parent
        visible: root.name === "queue"

        Repeater {
            model: 3

            delegate: Item {
                x: root.size * 0.1
                y: root.size * (0.18 + index * 0.27)
                width: root.size * 0.8
                height: Math.max(2, root.size * 0.12)

                Rectangle {
                    width: height
                    height: parent.height
                    radius: width / 2
                    color: root.color
                }

                Rectangle {
                    x: root.size * 0.2
                    width: root.size * 0.6
                    height: parent.height
                    radius: height / 2
                    color: root.color
                }
            }
        }
    }

    Item {
        id: teethLayer
        anchors.fill: parent
        visible: root.name === "settings"

        Repeater {
            model: 8

            delegate: Rectangle {
                width: Math.max(3, root.size * 0.18)
                height: Math.max(6, root.size * 0.34)
                x: (teethLayer.width - width) / 2
                y: 0
                radius: width / 2
                color: root.color

                transform: Rotation {
                    origin.x: width / 2
                    origin.y: teethLayer.height / 2
                    angle: index * 45
                }
            }
        }

        Rectangle {
            width: root.size * 0.62
            height: width
            anchors.centerIn: parent
            radius: width / 2
            color: "transparent"
            border.width: Math.max(2, root.size * 0.12)
            border.color: root.color
        }

        Rectangle {
            width: root.size * 0.24
            height: width
            anchors.centerIn: parent
            radius: width / 2
            color: root.color
        }
    }
}
