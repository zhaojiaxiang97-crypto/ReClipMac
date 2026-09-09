import QtQuick
import QtQuick.Controls
import QtQuick.Layouts

Item {
    id: root

    property alias text: urlField.text
    property bool busy: false
    property bool compact: width < 640
    property bool workspaceMode: false
    readonly property int workspaceHeight: 560

    signal parseRequested()
    signal pasteRequested()
    signal clearRequested()
    signal urlsDropped(var urls)

    implicitHeight: captureColumn.implicitHeight + 32
    Layout.fillHeight: root.workspaceMode
    Layout.minimumHeight: root.workspaceMode ? root.workspaceHeight : 0
    Layout.preferredHeight: root.workspaceMode ? root.workspaceHeight : implicitHeight

    Rectangle {
        anchors.fill: parent
        radius: Theme.radiusPanel
        color: Theme.surface
        border.width: 1
        border.color: dropArea.containsDrag ? Theme.accent : Theme.border

        Rectangle {
            anchors.left: parent.left
            anchors.right: parent.right
            anchors.bottom: parent.bottom
            anchors.margins: 1
            height: 3
            radius: 2
            color: Theme.violet
            visible: root.busy
            opacity: 0.9
        }
    }

    ColumnLayout {
        id: captureColumn
        anchors.fill: parent
        anchors.margins: 16
        spacing: 12

        RowLayout {
            Layout.fillWidth: true
            spacing: 10

            Rectangle {
                Layout.preferredWidth: 36
                Layout.preferredHeight: 36
                radius: Theme.radiusSmall
                color: Theme.violetSurface

                Text {
                    anchors.centerIn: parent
                    text: "01"
                    color: Theme.accent
                    font.family: Theme.fontFamily
                    font.pixelSize: 13
                    font.weight: Font.DemiBold
                }
            }

            ColumnLayout {
                Layout.fillWidth: true
                spacing: 2

                Label {
                    text: "添加媒体链接"
                    color: Theme.text
                    font.family: Theme.fontFamily
                    font.pixelSize: 15
                    font.weight: Font.DemiBold
                }

                Label {
                    text: root.compact ? "粘贴链接，确认后开始下载" : "支持多个公开链接，也可以直接拖入这里"
                    color: Theme.muted
                    font.family: Theme.fontFamily
                    font.pixelSize: 12
                }
            }

            Label {
                visible: !root.compact
                text: "Ctrl / ⌘ + Enter"
                color: Theme.subtle
                font.family: Theme.monoFamily
                font.pixelSize: 11
            }
        }

        TextArea {
            id: urlField
            Layout.fillWidth: true
            Layout.preferredHeight: root.compact ? 92 : 96
            placeholderText: "https://…"
            placeholderTextColor: Theme.subtle
            selectByMouse: true
            wrapMode: TextEdit.WrapAnywhere
            color: Theme.text
            font.family: Theme.monoFamily
            font.pixelSize: root.compact ? 13 : 13
            leftPadding: 13
            rightPadding: 13
            topPadding: 12
            bottomPadding: 12
            Accessible.name: "媒体链接输入框"
            Accessible.description: "输入一个或多个 HTTP 或 HTTPS 媒体链接，支持空格、逗号和换行分隔"

            background: Rectangle {
                radius: Theme.radiusControl
                color: Theme.surfaceAlt
                border.width: urlField.activeFocus ? 2 : 1
                border.color: urlField.activeFocus ? Theme.accent : Theme.border
            }

            Keys.onPressed: function (event) {
                if (event.key === Qt.Key_Return && (event.modifiers & Qt.ControlModifier || event.modifiers & Qt.MetaModifier)) {
                    root.parseRequested()
                    event.accepted = true
                }
            }
        }

        RowLayout {
            Layout.fillWidth: true
            spacing: 8

            Item {
                visible: !root.compact
                Layout.fillWidth: true
            }

            AppButton {
                visible: !root.compact
                text: "清空"
                variant: "ghost"
                compact: true
                enabled: !root.busy && urlField.text.length > 0
                onClicked: {
                    urlField.clear()
                    root.clearRequested()
                }
            }

            AppButton {
                Layout.fillWidth: root.compact
                text: "从剪贴板粘贴"
                iconText: "▣"
                variant: "secondary"
                compact: false
                enabled: !root.busy
                onClicked: root.pasteRequested()
            }

            AppButton {
                Layout.fillWidth: root.compact
                text: root.busy ? "正在解析" : "解析媒体"
                iconText: root.busy ? "◌" : "↓"
                variant: "primary"
                compact: false
                enabled: !root.busy && urlField.text.trim().length > 0
                onClicked: root.parseRequested()
            }
        }

        Rectangle {
            visible: root.workspaceMode
            Layout.fillWidth: true
            Layout.fillHeight: true
            Layout.minimumHeight: 132
            radius: Theme.radiusControl
            color: Qt.alpha(Theme.violetSurface, 0.45)
            border.width: 1
            border.color: dropArea.containsDrag ? Theme.accent : Qt.alpha(Theme.accent, 0.20)

            Column {
                anchors.centerIn: parent
                spacing: 6

                Label {
                    anchors.horizontalCenter: parent.horizontalCenter
                    text: "拖放链接到这里"
                    color: Theme.text
                    font.family: Theme.fontFamily
                    font.pixelSize: 15
                    font.weight: Font.DemiBold
                }

                Label {
                    anchors.horizontalCenter: parent.horizontalCenter
                    text: "支持一次解析多个公开媒体链接"
                    color: Theme.muted
                    font.family: Theme.fontFamily
                    font.pixelSize: 12
                }
            }
        }
    }

    DropArea {
        id: dropArea
        anchors.fill: parent
        z: 10

        onDropped: function (drop) {
            if (!drop.hasUrls) {
                return
            }
            var values = []
            for (var index = 0; index < drop.urls.length; ++index) {
                values.push(drop.urls[index].toString())
            }
            root.urlsDropped(values)
            drop.acceptProposedAction()
        }
    }

    Rectangle {
        anchors.fill: parent
        z: 11
        visible: dropArea.containsDrag
        radius: Theme.radiusPanel
        color: Qt.alpha(Theme.accent, 0.10)
        border.width: 2
        border.color: Theme.accent

        Column {
            anchors.centerIn: parent
            spacing: 4

            Text {
                anchors.horizontalCenter: parent.horizontalCenter
                text: "⌁"
                color: Theme.accent
                font.pixelSize: 30
                font.weight: Font.Bold
            }

            Label {
                text: "松开以解析链接"
                color: Theme.accent
                font.family: Theme.fontFamily
                font.pixelSize: 16
                font.weight: Font.DemiBold
            }
        }
    }
}
