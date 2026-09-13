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

    }

    ColumnLayout {
        id: captureColumn
        anchors.fill: parent
        anchors.margins: root.compact ? 16 : 20
        spacing: root.compact ? 12 : 10

        RowLayout {
            Layout.fillWidth: true
            spacing: 10

            Rectangle {
                visible: root.compact
                Layout.preferredWidth: visible ? 32 : 0
                Layout.preferredHeight: visible ? 32 : 0
                radius: width / 2
                color: Theme.violetSurface

                IconGlyph {
                    anchors.centerIn: parent
                    name: "link"
                    color: Theme.accent
                    size: 18
                }
            }

            Rectangle {
                visible: !root.compact
                Layout.preferredWidth: visible ? 36 : 0
                Layout.preferredHeight: visible ? 36 : 0
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
                    text: root.compact ? "粘贴媒体链接" : "添加媒体链接"
                    color: Theme.text
                    font.family: Theme.fontFamily
                    font.pixelSize: root.compact ? 15 : 16
                    font.weight: Font.DemiBold
                }

                Label {
                    text: root.compact ? "解析并下载视频或音频" : "支持公开链接，也可以直接拖入这里"
                    color: Theme.muted
                    font.family: Theme.fontFamily
                    font.pixelSize: 12
                }
            }

            Label {
                visible: false
                text: "Ctrl / ⌘ + Enter"
                color: Theme.subtle
                font.family: Theme.monoFamily
                font.pixelSize: 11
            }
        }

        TextArea {
            id: urlField
            Layout.fillWidth: true
            Layout.preferredHeight: root.compact ? 92 : 64
            placeholderText: root.compact ? "请粘贴视频或音频链接…" : "粘贴链接，确认后开始下载"
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
                color: root.compact ? Theme.surfaceAlt : Theme.surface
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
                visible: false
                text: "清空"
                iconName: "clear"
                variant: "ghost"
                compact: true
                enabled: !root.busy && urlField.text.length > 0
                onClicked: {
                    urlField.clear()
                    root.clearRequested()
                }
            }

            AppButton {
                Layout.fillWidth: false
                text: root.compact ? "粘贴" : "从剪贴板粘贴"
                iconName: "clipboard"
                variant: "secondary"
                compact: root.compact
                enabled: !root.busy
                onClicked: root.pasteRequested()
            }

            AppButton {
                Layout.fillWidth: true
                text: root.busy ? "正在解析" : "解析媒体"
                iconName: root.busy ? "loading" : "scan"
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

            IconGlyph {
                anchors.horizontalCenter: parent.horizontalCenter
                name: "link"
                color: Theme.accent
                size: 30
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
