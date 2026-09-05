import QtQuick
import QtQuick.Controls
import QtQuick.Layouts

Frame {
    id: root

    property string toolId
    property string displayName
    property bool available
    property bool checking
    property string version
    property string path
    property string customPath
    property string statusText

    signal pathSubmitted(string path)

    Layout.fillWidth: true

    background: Rectangle {
        color: Theme.surface
        radius: 12
        border.color: root.available ? Theme.successBorder : Theme.border
    }

    ColumnLayout {
        anchors.fill: parent
        spacing: 10

        RowLayout {
            Layout.fillWidth: true

            Label {
                text: root.displayName
                font.pixelSize: 17
                font.bold: true
            }

            Item { Layout.fillWidth: true }

            Label {
                text: root.checking ? "检测中…" : (root.available ? "已就绪" : "需要处理")
                color: root.available ? Theme.success : Theme.warning
                font.bold: true
            }
        }

        Label {
            Layout.fillWidth: true
            text: root.statusText
            color: root.available ? Theme.success : Theme.muted
            wrapMode: Text.Wrap
        }

        Label {
            Layout.fillWidth: true
            text: root.version.length > 0 ? "版本：" + root.version : "版本：—"
            color: Theme.muted
            elide: Text.ElideRight
        }

        Label {
            Layout.fillWidth: true
            text: root.path.length > 0 ? "路径：" + root.path : "路径：未找到"
            color: Theme.muted
            elide: Text.ElideMiddle
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
            }

            Button {
                text: "应用"
                enabled: !root.checking
                onClicked: root.pathSubmitted(pathField.text)
            }

            Button {
                text: "清除"
                enabled: !root.checking && root.customPath.length > 0
                onClicked: {
                    pathField.clear()
                    root.pathSubmitted("")
                }
            }
        }
    }
}
