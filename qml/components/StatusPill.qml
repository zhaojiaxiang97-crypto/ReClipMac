import QtQuick

Rectangle {
    id: root

    property string state: "idle"
    property string label: ""
    property bool compact: false

    readonly property color stateColor: Theme.stateColor(state)
    readonly property string displayLabel: label.length > 0 ? label : state

    implicitWidth: content.implicitWidth + (compact ? 18 : 22)
    implicitHeight: compact ? 24 : 28
    radius: height / 2
    color: Theme.stateSurface(state)
    border.width: 1
    border.color: Qt.rgba(stateColor.r, stateColor.g, stateColor.b, 0.34)

    Row {
        id: content
        anchors.centerIn: parent
        spacing: 7

        Rectangle {
            width: compact ? 6 : 7
            height: width
            radius: width / 2
            color: root.stateColor
            anchors.verticalCenter: parent.verticalCenter
        }

        Text {
            text: root.displayLabel
            color: root.stateColor
            font.family: Theme.fontFamily
            font.pixelSize: compact ? 11 : 12
            font.weight: Font.DemiBold
            anchors.verticalCenter: parent.verticalCenter
        }
    }
}
