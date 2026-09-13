import QtQuick
import QtQuick.Controls
import QtQuick.Dialogs
import QtQuick.Layouts
import org.kde.kirigami as Kirigami
import ReClip

Kirigami.ScrollablePage {
    id: root

    property var settings: null
    property var controller: null
    property var platformStorage: null
    property bool compact: width < 700
    readonly property bool mobilePlatform: Qt.platform.os === "android" || Qt.platform.os === "ios"

    FolderDialog {
        id: folderDialog
        title: "选择下载目录"
        onAccepted: {
            if (root.settings) {
                root.settings.downloadDirectory = selectedFolder.toLocalFile()
            }
        }
    }

    Connections {
        target: root.platformStorage

        function onExportDirectorySelected(uri, label) {
            if (root.mobilePlatform) {
                exportSuccessDialog.open()
            }
        }
    }

    AppDialog {
        id: exportSuccessDialog
        heading: "保存位置已设置"
        iconName: "check"
        tone: "success"
        message: "保存位置设置成功。"
        detail: "下载完成后，文件会保存到你选择的位置。"
        cancelText: ""
        confirmText: "知道了"
        showCancelButton: false
    }

    background: Rectangle {
        color: Theme.background
    }

    ColumnLayout {
        id: content
        width: Math.max(root.width - (root.compact ? 32 : Theme.pageGutter * 2), 0)
        x: root.compact ? 16 : Theme.pageGutter
        y: root.compact ? 16 : Theme.pageTop
        spacing: root.compact ? Kirigami.Units.largeSpacing : Theme.pageSpacing

        ColumnLayout {
            Layout.fillWidth: true
            spacing: 2

            Kirigami.Heading {
                text: "设置"
                color: Theme.text
                font.family: Theme.fontFamily
                font.pixelSize: root.compact ? 28 : 24
                font.weight: Font.DemiBold
            }

            Label {
                text: "管理下载文件保存位置。"
                color: Theme.muted
                font.family: Theme.fontFamily
                font.pixelSize: 13
            }
        }

        Kirigami.Card {
            Layout.fillWidth: true
            Layout.maximumWidth: 760
            Layout.alignment: Qt.AlignLeft
            visible: !root.mobilePlatform

            background: Rectangle {
                color: Theme.surface
                radius: Theme.radiusPanel
                border.width: 1
                border.color: Theme.border
            }

            contentItem: ColumnLayout {
                width: parent ? parent.width : 0
                spacing: Kirigami.Units.smallSpacing

                Label {
                    text: "下载目录"
                    color: Theme.text
                    font.family: Theme.fontFamily
                    font.pixelSize: 16
                    font.weight: Font.DemiBold
                }

                Label {
                    text: "下载完成后会保存到此文件夹"
                    color: Theme.muted
                    font.family: Theme.fontFamily
                    font.pixelSize: 12
                }

                RowLayout {
                    Layout.fillWidth: true
                    spacing: 8

                    AppTextField {
                        id: directoryField
                        Layout.fillWidth: true
                        text: root.settings ? root.settings.downloadDirectory : ""
                        selectByMouse: true
                        color: Theme.text
                        font.family: Theme.monoFamily
                        font.pixelSize: 13
                        placeholderText: "下载文件夹"
                    }

                    AppButton {
                        text: root.compact ? "选择" : "选择目录"
                        iconName: "folder"
                        variant: "secondary"
                        compact: true
                        onClicked: folderDialog.open()
                    }

                }

                RowLayout {
                    Layout.fillWidth: true

                    StatusPill {
                        state: root.settings && root.settings.downloadDirectoryValid ? "completed" : "failed"
                        label: root.settings ? root.settings.downloadDirectoryStatus : ""
                        compact: true
                    }

                    Item { Layout.fillWidth: true }

                    AppButton {
                        visible: !root.compact
                        text: "保存"
                        iconName: "check"
                        variant: "primary"
                        compact: true
                        onClicked: {
                            if (root.settings) {
                                root.settings.downloadDirectory = directoryField.text
                            }
                        }
                    }
                }

                AppButton {
                    visible: root.compact
                    Layout.fillWidth: true
                    text: "应用下载目录"
                    iconName: "check"
                    variant: "primary"
                    onClicked: {
                        if (root.settings) {
                            root.settings.downloadDirectory = directoryField.text
                        }
                    }
                }
            }
        }

        Kirigami.Card {
            Layout.fillWidth: true
            visible: root.mobilePlatform

            background: Rectangle {
                color: Theme.surface
                radius: Theme.radiusPanel
                border.width: 1
                border.color: Theme.border
            }

            contentItem: ColumnLayout {
                width: parent ? parent.width : 0
                spacing: Kirigami.Units.smallSpacing

                Kirigami.Heading {
                    text: "文件导出"
                    color: Theme.text
                    font.family: Theme.fontFamily
                }

                Label {
                    Layout.fillWidth: true
                    text: "选择保存位置后，下载完成的文件会导出到该位置。"
                    color: Theme.text
                    font.family: Theme.fontFamily
                    font.pixelSize: 14
                    wrapMode: Text.Wrap
                }

                Label {
                    Layout.fillWidth: true
                    text: "系统会记住你选择的保存位置。"
                    color: Theme.muted
                    font.family: Theme.fontFamily
                    font.pixelSize: 12
                    wrapMode: Text.Wrap
                }

                AppButton {
                    Layout.fillWidth: true
                    Layout.minimumWidth: 0
                    text: root.platformStorage && root.platformStorage.busy ? "正在处理" : "设置保存位置"
                    iconName: "folder-open"
                    variant: "primary"
                    enabled: root.platformStorage && !root.platformStorage.busy
                    onClicked: root.platformStorage.chooseExportDirectory()
                }

                Kirigami.InlineMessage {
                    Layout.fillWidth: true
                    visible: root.platformStorage && root.platformStorage.lastError.length > 0
                    type: Kirigami.MessageType.Error
                    text: root.platformStorage ? root.platformStorage.lastError : ""
                }
            }
        }

    }
}
