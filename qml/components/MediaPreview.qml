import QtQuick
import QtQuick.Controls
import QtQuick.Layouts

Item {
    id: root

    property var inspector: null
    property var settings: null
    property bool compact: width < 680
    property string outputFormat: settings ? settings.defaultOutputFormat : "mp4"

    signal downloadRequested(string format)
    signal queueRequested(string format)

    implicitHeight: previewColumn.implicitHeight + 32

    Rectangle {
        anchors.fill: parent
        radius: Theme.radiusPanel
        color: Theme.surface
        border.width: 1
        border.color: Theme.successBorder
    }

    ColumnLayout {
        id: previewColumn
        anchors.fill: parent
        anchors.margins: 16
        spacing: 16

        RowLayout {
            Layout.fillWidth: true
            spacing: 10

            Rectangle {
                Layout.preferredWidth: 32
                Layout.preferredHeight: 32
                radius: Theme.radiusSmall
                color: Theme.signalSurface

                Text {
                    anchors.centerIn: parent
                    text: "✓"
                    color: Theme.signal
                    font.family: Theme.fontFamily
                    font.pixelSize: 18
                    font.weight: Font.Bold
                }
            }

            ColumnLayout {
                Layout.fillWidth: true
                spacing: 2

                Label {
                    text: "媒体已准备好"
                    color: Theme.signal
                    font.family: Theme.fontFamily
                    font.pixelSize: 15
                    font.weight: Font.DemiBold
                }

                Label {
                    text: "确认输出格式后开始下载"
                    color: Theme.muted
                    font.family: Theme.fontFamily
                    font.pixelSize: 12
                }
            }

            StatusPill {
                state: "ready"
                label: "可下载"
                compact: true
            }
        }

        RowLayout {
            visible: !root.compact
            Layout.fillWidth: true
            spacing: 20

            Thumbnail {
                Layout.preferredWidth: 280
                Layout.preferredHeight: 158
                inspector: root.inspector
            }

            Details {
                Layout.fillWidth: true
                inspector: root.inspector
                settings: root.settings
                compact: false
                onDownloadRequested: function (format) { root.downloadRequested(format) }
                onQueueRequested: function (format) { root.queueRequested(format) }
            }
        }

        ColumnLayout {
            visible: root.compact
            Layout.fillWidth: true
            spacing: 14

            Thumbnail {
                Layout.fillWidth: true
                Layout.preferredHeight: Math.max(150, Math.min(210, root.width * 0.52))
                inspector: root.inspector
            }

            Details {
                Layout.fillWidth: true
                inspector: root.inspector
                settings: root.settings
                compact: true
                onDownloadRequested: function (format) { root.downloadRequested(format) }
                onQueueRequested: function (format) { root.queueRequested(format) }
            }
        }
    }

    component Thumbnail: Item {
        id: thumbnail
        property var inspector: null

        Rectangle {
            anchors.fill: parent
            radius: Theme.radiusControl
            color: Theme.surfaceAlt
            clip: true

            Image {
                id: previewImage
                anchors.fill: parent
                source: thumbnail.inspector ? thumbnail.inspector.thumbnailUrl : ""
                fillMode: Image.PreserveAspectCrop
                asynchronous: true
                visible: status === Image.Ready
            }

            Column {
                anchors.centerIn: parent
                spacing: 5
                visible: !previewImage.visible

                Text {
                    anchors.horizontalCenter: parent.horizontalCenter
                    text: "◈"
                    color: Theme.subtle
                    font.pixelSize: 26
                }

                Label {
                    text: "暂无缩略图"
                    color: Theme.subtle
                    font.family: Theme.fontFamily
                    font.pixelSize: 12
                }
            }
        }
    }

    component Details: ColumnLayout {
        id: details
        property var inspector: null
        property var settings: null
        property bool compact: false
        signal downloadRequested(string format)
        signal queueRequested(string format)

        spacing: 8

        Label {
            Layout.fillWidth: true
            text: details.inspector ? details.inspector.title : ""
            color: Theme.text
            font.family: Theme.fontFamily
            font.pixelSize: details.compact ? 18 : 19
            font.weight: Font.DemiBold
            wrapMode: Text.Wrap
            maximumLineCount: 3
            elide: Text.ElideRight
        }

        Label {
            Layout.fillWidth: true
            text: details.inspector && details.inspector.uploader.length > 0
                  ? "作者  " + details.inspector.uploader
                  : "作者  未知"
            color: Theme.muted
            font.family: Theme.fontFamily
            font.pixelSize: 13
            elide: Text.ElideRight
        }

        Label {
            Layout.fillWidth: true
            text: details.inspector && details.inspector.durationText.length > 0
                  ? "时长  " + details.inspector.durationText
                  : "时长  未知"
            color: Theme.muted
            font.family: Theme.fontFamily
            font.pixelSize: 13
        }

        Item { Layout.preferredHeight: 3 }

        ComboBox {
            id: formatCombo
            Layout.fillWidth: true
            model: ["MP4 视频", "MP3 音频"]
            currentIndex: details.settings && details.settings.defaultOutputFormat === "mp3" ? 1 : 0
            font.family: Theme.fontFamily
            font.pixelSize: 13

            contentItem: Text {
                leftPadding: 13
                rightPadding: 36
                text: formatCombo.displayText
                color: Theme.text
                font: formatCombo.font
                verticalAlignment: Text.AlignVCenter
                elide: Text.ElideRight
            }

            background: Rectangle {
                radius: Theme.radiusControl
                color: Theme.surfaceAlt
                border.width: formatCombo.visualFocus ? 2 : 1
                border.color: formatCombo.visualFocus ? Theme.accent : Theme.border
            }

            onActivated: function (index) {
                if (details.settings) {
                    details.settings.defaultOutputFormat = index === 1 ? "mp3" : "mp4"
                }
            }
        }

        ComboBox {
            id: qualityCombo
            visible: formatCombo.currentIndex === 0
            Layout.fillWidth: true
            model: details.inspector ? details.inspector.formatLabels : []
            currentIndex: details.inspector && details.inspector.formatLabels.length > 0 ? 0 : -1
            enabled: model.length > 0
            font.family: Theme.fontFamily
            font.pixelSize: 13

            contentItem: Text {
                leftPadding: 13
                rightPadding: 36
                text: qualityCombo.displayText.length > 0 ? qualityCombo.displayText : "选择清晰度"
                color: qualityCombo.enabled ? Theme.text : Theme.subtle
                font: qualityCombo.font
                verticalAlignment: Text.AlignVCenter
                elide: Text.ElideRight
            }

            background: Rectangle {
                radius: Theme.radiusControl
                color: Theme.surfaceAlt
                border.width: qualityCombo.visualFocus ? 2 : 1
                border.color: qualityCombo.visualFocus ? Theme.accent : Theme.border
            }

            onActivated: function (index) {
                if (details.inspector && index >= 0 && index < details.inspector.formats.length) {
                    details.inspector.selectedFormatId = details.inspector.formats[index].id
                }
            }
        }

        RowLayout {
            Layout.fillWidth: true
            spacing: 8

            AppButton {
                Layout.fillWidth: true
                text: details.settings && details.settings.defaultOutputFormat === "mp3" ? "下载 MP3" : "下载 MP4"
                iconText: "↓"
                variant: "primary"
                onClicked: details.downloadRequested(details.settings ? details.settings.defaultOutputFormat : "mp4")
            }

            AppButton {
                visible: !details.compact
                text: "加入队列"
                iconText: "+"
                variant: "secondary"
                onClicked: details.queueRequested(details.settings ? details.settings.defaultOutputFormat : "mp4")
            }
        }

        AppButton {
            visible: details.compact
            Layout.fillWidth: true
            text: "加入下载队列"
            iconText: "+"
            variant: "secondary"
            onClicked: details.queueRequested(details.settings ? details.settings.defaultOutputFormat : "mp4")
        }
    }
}
