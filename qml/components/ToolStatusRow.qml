import QtQuick
import QtQuick.Controls
import QtQuick.Layouts

Item {
    id: root

    property string displayName: ""
    property bool available: false
    property bool checking: false
    property string version: ""
    property string path: ""
    property string customPath: ""
    property string statusText: ""

    signal pathSubmitted(string path)
    signal clearRequested()

    readonly property bool compact: width < 700

    implicitHeight: content.implicitHeight + (compact ? 20 : 28)

    Rectangle {
        anchors.fill: parent
        radius: root.compact ? 0 : Theme.radiusPanel
        color: root.compact ? "transparent" : Theme.surface
        border.width: root.compact ? 0 : 1
        border.color: root.available ? Theme.successBorder : Theme.border

        Rectangle {
            visible: root.compact
            anchors.left: parent.left
            anchors.right: parent.right
            anchors.bottom: parent.bottom
            height: 1
            color: Theme.border
        }
    }

    ColumnLayout {
        id: content
        anchors.fill: parent
        anchors.margins: root.compact ? 0 : 14
        spacing: root.compact ? 8 : 9

        RowLayout {
            Layout.fillWidth: true

            Label {
                text: root.displayName
                color: Theme.text
                font.family: Theme.fontFamily
                font.pixelSize: 15
                font.weight: Font.DemiBold
            }

            Item { Layout.fillWidth: true }

            StatusPill {
                state: root.checking ? "downloading" : (root.available ? "completed" : "failed")
                label: root.checking ? "检测中" : (root.available ? "已就绪" : "需要处理")
                compact: true
            }
        }

        Label {
            Layout.fillWidth: true
            text: root.statusText
            color: root.available ? Theme.signal : Theme.muted
            font.family: Theme.fontFamily
            font.pixelSize: 12
            wrapMode: Text.Wrap
        }

        RowLayout {
            Layout.fillWidth: true
            spacing: 12

            Label {
                Layout.fillWidth: true
                text: root.version.length > 0 ? "版本  " + root.version : "版本  —"
                color: Theme.muted
                font.family: Theme.monoFamily
                font.pixelSize: 11
                elide: Text.ElideRight
            }

            Label {
                Layout.fillWidth: true
                text: root.path.length > 0
                      ? "路径  " + root.path
                      : (root.available ? "来源  Android 内置运行时" : "路径  未找到")
                color: Theme.muted
                font.family: Theme.monoFamily
                font.pixelSize: 11
                elide: Text.ElideMiddle
            }
        }

        RowLayout {
            Layout.fillWidth: true
            spacing: 8

            TextField {
                id: pathField
                Layout.fillWidth: true
                text: root.customPath
                placeholderText: "可选：指定自定义可执行文件路径"
                selectByMouse: true
                font.family: Theme.monoFamily
                font.pixelSize: 11
                color: Theme.text

                background: Rectangle {
                    radius: Theme.radiusSmall
                    color: Theme.background
                    border.width: pathField.activeFocus ? 2 : 1
                    border.color: pathField.activeFocus ? Theme.violet : Theme.border
                }
            }

            AppButton {
                text: "应用"
                variant: "secondary"
                compact: true
                enabled: !root.checking
                onClicked: root.pathSubmitted(pathField.text)
            }

            AppButton {
                text: "清除"
                variant: "ghost"
                compact: true
                visible: root.customPath.length > 0
                enabled: !root.checking
                onClicked: {
                    pathField.clear()
                    root.clearRequested()
                }
            }
        }
    }
}
