import QtQuick
import QtQuick.Controls
import QtQuick.Layouts

Item {
    id: root

    property var settings: null
    property var controller: null

    ScrollView {
        id: scroll
        anchors.fill: parent
        clip: true
        contentWidth: Math.max(availableWidth || 0, 0)

        ColumnLayout {
            id: content
            width: Math.max((scroll.availableWidth || 0) - 32, 0)
            x: 16
            y: 16
            spacing: 16

            ColumnLayout {
                Layout.fillWidth: true
                spacing: 3

                Label {
                    text: "设置"
                    color: Theme.text
                    font.family: Theme.fontFamily
                    font.pixelSize: 28
                    font.weight: Font.DemiBold
                }

                Label {
                    text: "文件保存和下载范围"
                    color: Theme.muted
                    font.family: Theme.fontFamily
                    font.pixelSize: 13
                }
            }

            Rectangle {
                Layout.fillWidth: true
                implicitHeight: storageColumn.implicitHeight + 28
                radius: Theme.radiusPanel
                color: Theme.surface
                border.width: 1
                border.color: Theme.border

                ColumnLayout {
                    id: storageColumn
                    anchors.fill: parent
                    anchors.margins: 14
                    spacing: 9

                    RowLayout {
                        Layout.fillWidth: true
                        spacing: 9

                        Rectangle {
                            Layout.preferredWidth: 28
                            Layout.preferredHeight: 28
                            radius: 14
                            color: Theme.signalSurface

                            Text {
                                anchors.centerIn: parent
                                text: "✓"
                                color: Theme.signal
                                font.pixelSize: 16
                                font.weight: Font.Bold
                            }
                        }

                        ColumnLayout {
                            Layout.fillWidth: true
                            spacing: 1

                            Label {
                                text: "文件保存"
                                color: Theme.text
                                font.family: Theme.fontFamily
                                font.pixelSize: 15
                                font.weight: Font.DemiBold
                            }

                            Label {
                                text: "下载完成后可在“文件”App 中查看"
                                color: Theme.muted
                                font.family: Theme.fontFamily
                                font.pixelSize: 12
                            }
                        }
                    }

                    Rectangle {
                        Layout.fillWidth: true
                        implicitHeight: pathLabel.implicitHeight + 20
                        radius: Theme.radiusControl
                        color: Theme.surfaceAlt

                        Label {
                            id: pathLabel
                            anchors.fill: parent
                            anchors.margins: 10
                            text: root.settings ? root.settings.downloadDirectory : "Documents/ReClip"
                            color: Theme.muted
                            font.family: Theme.monoFamily
                            font.pixelSize: 11
                            elide: Text.ElideMiddle
                            verticalAlignment: Text.AlignVCenter
                        }
                    }
                }
            }

            Rectangle {
                Layout.fillWidth: true
                implicitHeight: policyColumn.implicitHeight + 28
                radius: Theme.radiusPanel
                color: Theme.surface
                border.width: 1
                border.color: Theme.border

                ColumnLayout {
                    id: policyColumn
                    anchors.fill: parent
                    anchors.margins: 14
                    spacing: 7

                    Label {
                        text: "下载方式"
                        color: Theme.text
                        font.family: Theme.fontFamily
                        font.pixelSize: 15
                        font.weight: Font.DemiBold
                    }

                    Label {
                        Layout.fillWidth: true
                        text: "仅处理 HTTPS 直接音视频链接，保留原始格式。"
                        color: Theme.muted
                        font.family: Theme.fontFamily
                        font.pixelSize: 12
                        wrapMode: Text.Wrap
                    }
                }
            }

            InlineNotice {
                Layout.fillWidth: true
                tone: "info"
                title: "仅保存你有权保存的非 DRM 内容"
                body: "网页解析、转码和受保护内容不在 iOS 版本范围内。"
            }

            Label {
                Layout.fillWidth: true
                text: root.controller ? "Video Downloader  ·  " + root.controller.qtVersion : "Video Downloader"
                color: Theme.subtle
                font.family: Theme.monoFamily
                font.pixelSize: 11
                horizontalAlignment: Text.AlignHCenter
                bottomPadding: 12
            }
        }
    }
}
