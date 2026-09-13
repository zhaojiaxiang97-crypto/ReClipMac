import QtQuick
import QtQuick.Controls
import QtQuick.Dialogs
import QtQuick.Layouts

Item {
    id: root

    property var settings: null
    property var controller: null
    property var platformStorage: null
    property bool compact: width < 700
    readonly property bool mobilePlatform: Qt.platform.os === "android" || Qt.platform.os === "ios"
    readonly property bool iosPlatform: Qt.platform.os === "ios"

    function openFolderDialog() {
        if (folderDialogLoader.item) {
            folderDialogLoader.item.open()
        }
    }

    Loader {
        id: folderDialogLoader
        active: !root.mobilePlatform
        sourceComponent: Component {
            FolderDialog {
                title: "选择下载目录"
                onAccepted: {
                    if (root.settings) {
                        root.settings.downloadDirectory = selectedFolder.toLocalFile()
                    }
                }
            }
        }
    }

    Connections {
        target: root.platformStorage

        function onExportDirectorySelected(uri, label) {
            if (!root.iosPlatform) {
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

    ScrollView {
        id: scroll
        anchors.fill: parent
        clip: true
        contentWidth: Math.max(availableWidth || 0, 0)

        ColumnLayout {
            id: content
            width: Math.max((scroll.availableWidth || 0) - (root.compact ? 32 : Theme.pageGutter * 2), 0)
            x: root.compact ? 16 : Theme.pageGutter
            y: root.compact ? 16 : Theme.pageTop
            spacing: root.compact ? 16 : Theme.pageSpacing

            ColumnLayout {
                Layout.fillWidth: true
                spacing: 4

                Label {
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

            SectionTitle {
                visible: !root.mobilePlatform
                text: "下载位置"
            }

            Rectangle {
                visible: !root.mobilePlatform
                Layout.fillWidth: true
                implicitHeight: directoryColumn.implicitHeight + 28
                radius: Theme.radiusPanel
                color: Theme.surface
                border.width: 1
                border.color: Theme.border

                ColumnLayout {
                    id: directoryColumn
                    anchors.fill: parent
                    anchors.margins: 14
                    spacing: 10

                    Label {
                        text: "保存到"
                        color: Theme.text
                        font.family: Theme.fontFamily
                        font.pixelSize: 14
                        font.weight: Font.DemiBold
                    }

                    RowLayout {
                        Layout.fillWidth: true
                        spacing: 8

                        TextField {
                            id: directoryField
                            Layout.fillWidth: true
                            text: root.settings ? root.settings.downloadDirectory : ""
                            selectByMouse: true
                            color: Theme.text
                            font.family: Theme.monoFamily
                            font.pixelSize: 11

                            background: Rectangle {
                                radius: Theme.radiusSmall
                                color: Theme.background
                                border.width: directoryField.activeFocus ? 2 : 1
                                border.color: directoryField.activeFocus ? Theme.accent : Theme.border
                            }
                        }

                        AppButton {
                            text: root.compact ? "选择" : "选择目录"
                            iconName: "folder"
                            variant: "secondary"
                            compact: true
                            onClicked: root.openFolderDialog()
                        }

                        AppButton {
                            visible: !root.compact
                            text: "应用"
                            variant: "primary"
                            compact: true
                            onClicked: root.settings.downloadDirectory = directoryField.text
                        }
                    }

                    Label {
                        Layout.fillWidth: true
                        text: root.settings ? root.settings.downloadDirectoryStatus : ""
                        color: root.settings && root.settings.downloadDirectoryValid ? Theme.signal : Theme.warningText
                        font.family: Theme.fontFamily
                        font.pixelSize: 12
                        wrapMode: Text.Wrap
                    }

                    AppButton {
                        visible: root.compact
                        text: "应用下载目录"
                        Layout.fillWidth: true
                        variant: "primary"
                        onClicked: root.settings.downloadDirectory = directoryField.text
                    }
                }
            }

            SectionTitle {
                visible: root.mobilePlatform
                text: root.iosPlatform ? "文件保存" : "文件导出"
            }

            Rectangle {
                visible: root.mobilePlatform
                Layout.fillWidth: true
                implicitHeight: exportColumn.implicitHeight + 28
                radius: Theme.radiusPanel
                color: Theme.surface
                border.width: 1
                border.color: Theme.border

                ColumnLayout {
                    id: exportColumn
                    anchors.fill: parent
                    anchors.margins: 14
                    spacing: 10

                    Label {
                        Layout.fillWidth: true
                        text: root.iosPlatform
                              ? "文件保存在“文件”App 的 ReClip 文件夹。"
                              : "选择保存位置后，下载完成的文件会导出到该位置。"
                        color: Theme.text
                        font.family: Theme.fontFamily
                        font.pixelSize: 14
                        font.weight: Font.DemiBold
                        wrapMode: Text.Wrap
                    }

                    Label {
                        Layout.fillWidth: true
                        text: root.iosPlatform
                              ? "下载完成后可在传输队列中打开文件。"
                              : "系统会记住你选择的保存位置。"
                        color: Theme.muted
                        font.family: Theme.fontFamily
                        font.pixelSize: 12
                        wrapMode: Text.Wrap
                    }

                    AppButton {
                        visible: !root.iosPlatform
                        Layout.fillWidth: true
                        Layout.minimumWidth: 0
                        text: root.platformStorage && root.platformStorage.busy ? "正在处理" : "设置保存位置"
                        iconName: "folder-open"
                        variant: "primary"
                        enabled: root.platformStorage && !root.platformStorage.busy
                        onClicked: root.platformStorage.chooseExportDirectory()
                    }

                    InlineNotice {
                        Layout.fillWidth: true
                        visible: root.platformStorage && root.platformStorage.lastError.length > 0
                        tone: "danger"
                        title: "导出目录不可用"
                        body: root.platformStorage ? root.platformStorage.lastError : ""
                    }
                }
            }

            InlineNotice {
                Layout.fillWidth: true
                visible: root.iosPlatform
                tone: "info"
                title: "iOS 原生下载"
                body: "仅支持 HTTPS 直接音视频文件链接；文件会保留原始格式。"
            }

        }
    }

    component SectionTitle: Label {
        Layout.fillWidth: true
        topPadding: 10
        bottomPadding: 0
        color: Theme.text
        font.family: Theme.fontFamily
        font.pixelSize: 17
        font.weight: Font.Medium
    }

}
