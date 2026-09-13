import QtQuick
import QtQuick.Controls
import QtQuick.Layouts

Item {
    id: root

    property var inspector: null
    property var settings: null
    property bool compact: width < 680
    property string outputFormat: settings ? settings.defaultOutputFormat : "mp4"
    readonly property bool iosPlatform: Qt.platform.os === "ios"

    signal downloadRequested(string format)
    signal queueRequested(string format)

    implicitHeight: previewColumn.implicitHeight + 32

    Rectangle {
        anchors.fill: parent
        radius: Theme.radiusPanel
        color: Theme.surface
        border.width: 1
        border.color: Theme.border
    }

    ColumnLayout {
        id: previewColumn
        anchors.fill: parent
        anchors.margins: root.compact ? 16 : 24
        spacing: root.compact ? 12 : 14

        RowLayout {
            Layout.fillWidth: true
            spacing: root.compact ? 10 : 0

            Rectangle {
                visible: root.compact
                Layout.preferredWidth: visible ? 32 : 0
                Layout.preferredHeight: visible ? 32 : 0
                radius: Theme.radiusSmall
                color: Theme.signalSurface

                IconGlyph {
                    anchors.centerIn: parent
                    name: "check"
                    color: Theme.signal
                    size: 18
                }
            }

            ColumnLayout {
                Layout.fillWidth: true
                spacing: 2

                Label {
                    text: root.compact
                          ? (root.iosPlatform ? "原始媒体已准备好" : "媒体已准备好")
                          : "媒体预览"
                    color: root.compact ? Theme.signal : Theme.text
                    font.family: Theme.fontFamily
                    font.pixelSize: root.compact ? 15 : 17
                    font.weight: Font.DemiBold
                }

                Label {
                    visible: root.compact
                    text: root.iosPlatform ? "iOS 将保留原始格式，不做转码" : "确认输出格式后开始下载"
                    color: Theme.muted
                    font.family: Theme.fontFamily
                    font.pixelSize: 12
                }
            }

            StatusPill {
                state: "ready"
                label: root.compact ? "可下载" : "已解析"
                compact: true
            }
        }

        RowLayout {
            visible: !root.compact
            Layout.fillWidth: true
            spacing: 24

            Thumbnail {
                Layout.preferredWidth: 260
                Layout.preferredHeight: 146
                inspector: root.inspector
            }

            Details {
                Layout.fillWidth: true
                inspector: root.inspector
                settings: root.settings
                compact: false
                iosPlatform: root.iosPlatform
                onDownloadRequested: function (format) { root.downloadRequested(format) }
                onQueueRequested: function (format) { root.queueRequested(format) }
            }
        }

        RowLayout {
            visible: root.compact
            Layout.fillWidth: true
            spacing: 12

            Thumbnail {
                Layout.preferredWidth: Math.max(112, Math.min(128, root.width * 0.30))
                Layout.preferredHeight: 150
                Layout.alignment: Qt.AlignTop
                inspector: root.inspector
            }

            Details {
                Layout.fillWidth: true
                Layout.alignment: Qt.AlignTop
                inspector: root.inspector
                settings: root.settings
                compact: true
                iosPlatform: root.iosPlatform
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

                IconGlyph {
                    anchors.horizontalCenter: parent.horizontalCenter
                    name: "video"
                    color: Theme.subtle
                    size: 26
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
        property bool iosPlatform: false
        signal downloadRequested(string format)
        signal queueRequested(string format)

        spacing: details.compact ? 6 : 8

        Label {
            Layout.fillWidth: true
            text: details.inspector ? details.inspector.title : ""
            color: Theme.text
            font.family: Theme.fontFamily
            font.pixelSize: details.compact ? 16 : 21
            font.weight: Font.DemiBold
            wrapMode: Text.Wrap
            maximumLineCount: details.compact ? 2 : 3
            elide: Text.ElideRight
        }

        Label {
            Layout.fillWidth: true
            text: details.inspector && details.inspector.uploader.length > 0
                  ? "作者  " + details.inspector.uploader
                  : "作者  未知"
            color: Theme.muted
            font.family: Theme.fontFamily
            font.pixelSize: details.compact ? 12 : 13
            elide: Text.ElideRight
        }

        Label {
            Layout.fillWidth: true
            text: details.inspector && details.inspector.durationText.length > 0
                  ? "时长  " + details.inspector.durationText
                  : "时长  未知"
            color: Theme.muted
            font.family: Theme.fontFamily
            font.pixelSize: details.compact ? 12 : 13
        }

        Item { Layout.preferredHeight: 3 }

        Label {
            visible: details.iosPlatform
            Layout.fillWidth: true
            text: "格式  原始文件（不转换）"
            color: Theme.muted
            font.family: Theme.fontFamily
            font.pixelSize: 13
        }

        GridLayout {
            id: formatGrid
            Layout.fillWidth: true
            columns: 2
            columnSpacing: 8
            rowSpacing: 8

            ColumnLayout {
                id: formatField
                visible: !details.iosPlatform
                Layout.fillWidth: true
                Layout.columnSpan: qualityCombo.visible ? 1 : 2
                spacing: 4

                Label {
                    text: "格式"
                    color: Theme.muted
                    font.family: Theme.fontFamily
                    font.pixelSize: 11
                }

                AppSelect {
                    id: formatCombo
                    Layout.fillWidth: true
                    Layout.minimumWidth: 0
                    Layout.preferredHeight: details.compact ? 46 : 40
                    model: ["MP4 视频", "MP3 音频"]
                    currentIndex: details.settings && details.settings.defaultOutputFormat === "mp3" ? 1 : 0
                    compact: details.compact
                    compactText: formatCombo.currentIndex === 1 ? "MP3" : "MP4"

                    onActivated: function (index) {
                        if (details.settings) {
                            details.settings.defaultOutputFormat = index === 1 ? "mp3" : "mp4"
                        }
                    }
                }
            }

            ColumnLayout {
                id: qualityField
                visible: !details.iosPlatform && formatCombo.currentIndex === 0
                Layout.fillWidth: true
                spacing: 4

                Label {
                    text: "画质"
                    color: Theme.muted
                    font.family: Theme.fontFamily
                    font.pixelSize: 11
                }

                AppSelect {
                    id: qualityCombo
                    Layout.fillWidth: true
                    Layout.minimumWidth: 0
                    Layout.preferredHeight: details.compact ? 46 : 40
                    model: details.inspector ? details.inspector.formatLabels : []
                    currentIndex: details.inspector && details.inspector.formatLabels.length > 0 ? 0 : -1
                    enabled: model.length > 0
                    emptyText: details.compact ? "选择" : "选择清晰度"

                    onActivated: function (index) {
                        if (details.inspector && index >= 0 && index < details.inspector.formats.length) {
                            details.inspector.selectedFormatId = details.inspector.formats[index].id
                        }
                    }
                }
            }
        }

        RowLayout {
            Layout.fillWidth: true
            spacing: 8

            AppButton {
                Layout.fillWidth: true
                Layout.minimumWidth: 0
                Layout.preferredWidth: details.compact ? 1 : -1
                text: details.iosPlatform ? "下载原始媒体"
                      : (details.compact ? "下载" : (details.settings && details.settings.defaultOutputFormat === "mp3" ? "下载 MP3" : "下载 MP4"))
                iconName: "download"
                variant: "primary"
                onClicked: details.downloadRequested(details.iosPlatform ? "mp4"
                                                      : (details.settings ? details.settings.defaultOutputFormat : "mp4"))
            }

            AppButton {
                Layout.fillWidth: details.compact
                Layout.minimumWidth: 0
                Layout.preferredWidth: details.compact ? 1 : -1
                text: "加入队列"
                iconName: "queue"
                variant: "secondary"
                onClicked: details.queueRequested(details.iosPlatform ? "mp4"
                                                    : (details.settings ? details.settings.defaultOutputFormat : "mp4"))
            }
        }

    }
}
