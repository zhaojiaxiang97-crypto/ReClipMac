import QtQuick

Item {
    id: root

    property real progress: 0
    property string state: "idle"
    property bool indeterminate: false
    property bool showMarker: true

    implicitHeight: 16

    function boundedProgress() {
        return Math.max(0, Math.min(1, root.progress))
    }

    Rectangle {
        anchors.left: parent.left
        anchors.right: parent.right
        anchors.verticalCenter: parent.verticalCenter
        height: 2
        radius: 1
        color: Theme.border
    }

    Rectangle {
        id: progressLine
        anchors.left: parent.left
        anchors.verticalCenter: parent.verticalCenter
        width: root.indeterminate ? 0 : parent.width * root.boundedProgress()
        height: 3
        radius: 2
        color: Theme.stateColor(root.state)

        Behavior on width {
            NumberAnimation { duration: 220; easing.type: Easing.OutCubic }
        }
    }

    Rectangle {
        id: sweep
        visible: root.indeterminate
        width: Math.max(36, parent.width * 0.24)
        height: 3
        radius: 2
        color: Theme.violet
        y: (parent.height - height) / 2

        SequentialAnimation on x {
            loops: Animation.Infinite
            running: root.indeterminate
            PropertyAnimation { from: -sweep.width; to: root.width; duration: 900; easing.type: Easing.InOutQuad }
            PauseAnimation { duration: 120 }
        }
    }

    Rectangle {
        visible: root.showMarker && !root.indeterminate
        width: 10
        height: 10
        radius: 5
        x: Math.max(0, Math.min(parent.width - width, parent.width * root.boundedProgress() - width / 2))
        y: (parent.height - height) / 2
        color: Theme.stateColor(root.state)
        border.width: 2
        border.color: Theme.background
    }
}
