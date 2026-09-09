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
    property bool detailsExpanded: false

    signal pathSubmitted(string path)
    signal clearRequested()

    readonly property bool narrow: width < 640

    implicitHeight: content.implicitHeight + 24

    Rectangle {
        anchors.fill: parent
        radius: Theme.radiusSmall
        color: Theme.surfaceAlt
        border.width: 1
        border.color: root.available ? Theme.successBorder : Theme.border
    }

    ColumnLayout {
        id: content
        anchors.fill: parent
        anchors.margins: 12
        spacing: 8

        RowLayout {
            Layout.fillWidth: true
            spacing: 10

            Label {
                text: root.displayName
                color: Theme.text
                font.family: Theme.fontFamily
                font.pixelSize: 14
                font.weight: Font.DemiBold
            }

            Label {
                Layout.fillWidth: true
                visible: !root.narrow
                text: root.path.length > 0 ? root.path : root.statusText
                color: Theme.muted
                font.family: Theme.monoFamily
                font.pixelSize: 11
                elide: Text.ElideMiddle
            }

            StatusPill {
                state: root.checking ? "downloading" : (root.available ? "completed" : "failed")
                label: root.checking ? "检测中" : (root.available ? "已就绪" : "需要处理")
                compact: true
            }

            ToolButton {
                text: root.detailsExpanded ? "收起" : "配置"
                onClicked: root.detailsExpanded = !root.detailsExpanded
            }
        }

        ColumnLayout {
            Layout.fillWidth: true
            visible: root.detailsExpanded
            spacing: 6

            Label {
                Layout.fillWidth: true
                text: root.statusText
                color: root.available ? Theme.signal : Theme.warningText
                font.family: Theme.fontFamily
                font.pixelSize: 12
                wrapMode: Text.Wrap
            }

            Label {
                text: "版本"
                color: Theme.muted
                font.family: Theme.fontFamily
                font.pixelSize: 11
            }

            AppTextField {
                Layout.fillWidth: true
                text: root.version
                readOnly: true
                selectByMouse: true
                placeholderText: "未检测到版本信息"
                font.family: Theme.monoFamily
                font.pixelSize: 11
            }

            Label {
                text: "当前路径"
                color: Theme.muted
                font.family: Theme.fontFamily
                font.pixelSize: 11
            }

            AppTextField {
                Layout.fillWidth: true
                text: root.path
                readOnly: true
                selectByMouse: true
                placeholderText: "未找到可执行文件"
                font.family: Theme.monoFamily
                font.pixelSize: 11
            }

            Label {
                text: "自定义路径"
                color: Theme.muted
                font.family: Theme.fontFamily
                font.pixelSize: 11
            }

            RowLayout {
                Layout.fillWidth: true
                spacing: 8

                AppTextField {
                    id: pathField
                    Layout.fillWidth: true
                    text: root.customPath
                    placeholderText: "可选：指定自定义可执行文件路径"
                    selectByMouse: true
                    font.family: Theme.monoFamily
                    font.pixelSize: 11
                    color: Theme.text
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
}
