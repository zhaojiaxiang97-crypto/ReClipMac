import QtQuick
import QtQuick.Controls
import QtQuick.Layouts

Item {
    id: root

    property alias text: urlField.text
    property bool busy: false
    property bool compact: width < 640

    signal parseRequested()
    signal pasteRequested()
    signal clearRequested()
    signal urlsDropped(var urls)

    implicitHeight: captureColumn.implicitHeight + 32

    Rectangle {
        anchors.fill: parent
        radius: Theme.radiusInput
        color: Theme.surface
        border.width: 1
        border.color: dropArea.containsDrag ? Theme.violet : Theme.border

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

            ColumnLayout {
                Layout.fillWidth: true
                spacing: 2

                Label {
                    text: "媒体链接"
                    color: Theme.text
                    font.family: Theme.fontFamily
                    font.pixelSize: 16
                    font.weight: Font.DemiBold
                }

                Label {
                    text: root.compact ? "粘贴链接，确认后开始下载" : "粘贴一个或多个链接，先确认媒体信息，再选择输出格式"
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
            Layout.preferredHeight: root.compact ? 96 : 112
            placeholderText: "https://…"
            placeholderTextColor: Theme.subtle
            selectByMouse: true
            wrapMode: TextEdit.WrapAnywhere
            color: Theme.text
            font.family: Theme.monoFamily
            font.pixelSize: root.compact ? 13 : 12
            leftPadding: 13
            rightPadding: 13
            topPadding: 12
            bottomPadding: 12
            Accessible.name: "媒体链接输入框"
            Accessible.description: "输入一个或多个 HTTP 或 HTTPS 媒体链接，支持空格、逗号和换行分隔"

            background: Rectangle {
                radius: Theme.radiusControl
                color: Theme.background
                border.width: urlField.activeFocus ? 2 : 1
                border.color: urlField.activeFocus ? Theme.violet : Theme.border
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

            AppButton {
                Layout.fillWidth: root.compact
                text: root.busy ? "正在解析" : "解析媒体"
                iconText: root.busy ? "◌" : "⌁"
                variant: "primary"
                enabled: !root.busy && urlField.text.trim().length > 0
                onClicked: root.parseRequested()
            }

            AppButton {
                Layout.fillWidth: root.compact
                text: "从剪贴板粘贴"
                iconText: "▣"
                variant: "secondary"
                enabled: !root.busy
                onClicked: root.pasteRequested()
            }

            AppButton {
                visible: !root.compact
                text: "清空"
                variant: "ghost"
                enabled: !root.busy && urlField.text.length > 0
                onClicked: {
                    urlField.clear()
                    root.clearRequested()
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
        radius: Theme.radiusInput
        color: Qt.rgba(108 / 255, 92 / 255, 231 / 255, 0.10)
        border.width: 2
        border.color: Theme.violet

        Column {
            anchors.centerIn: parent
            spacing: 4

            Text {
                anchors.horizontalCenter: parent.horizontalCenter
                text: "⌁"
                color: Theme.violet
                font.pixelSize: 30
                font.weight: Font.Bold
            }

            Label {
                text: "松开以解析链接"
                color: Theme.violet
                font.family: Theme.fontFamily
                font.pixelSize: 16
                font.weight: Font.DemiBold
            }
        }
    }
}
