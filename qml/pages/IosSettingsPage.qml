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

                            IconGlyph {
                                anchors.centerIn: parent
                                name: "check"
                                color: Theme.signal
                                size: 16
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

        }
    }
}
