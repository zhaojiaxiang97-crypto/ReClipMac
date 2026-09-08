import QtQuick
import QtQuick.Controls
import QtQuick.Dialogs
import QtQuick.Layouts

Item {
    id: root

    property var settings: null
    property var tools: null
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

    ScrollView {
        id: scroll
        anchors.fill: parent
        clip: true
        contentWidth: availableWidth

        ColumnLayout {
            id: content
            width: Math.max(scroll.availableWidth - (root.compact ? 32 : Theme.pageGutter * 2), 0)
            x: root.compact ? 16 : Theme.pageGutter
            y: root.compact ? 16 : Theme.pageTop
            spacing: root.compact ? 16 : Theme.pageSpacing

            ColumnLayout {
                Layout.fillWidth: true
                spacing: 4
                visible: !root.compact

                Label {
                    text: "设置"
                    color: Theme.text
                    font.family: Theme.fontFamily
                    font.pixelSize: root.compact ? 28 : 24
                    font.weight: Font.DemiBold
                }

                Label {
                    text: "调整下载目录、工具路径和默认行为。"
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
                            iconText: "□"
                            variant: "secondary"
                            compact: true
                            onClicked: folderDialog.open()
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
                text: "文件导出"
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
                        text: "临时文件保存在应用私有目录"
                        color: Theme.text
                        font.family: Theme.fontFamily
                        font.pixelSize: 14
                        font.weight: Font.DemiBold
                    }

                    TextField {
                        Layout.fillWidth: true
                        text: root.settings ? root.settings.downloadDirectory : ""
                        readOnly: true
                        color: Theme.muted
                        font.family: Theme.monoFamily
                        font.pixelSize: 11

                        background: Rectangle {
                            radius: Theme.radiusSmall
                            color: Theme.background
                            border.width: 1
                            border.color: Theme.border
                        }
                    }

                    Label {
                        Layout.fillWidth: true
                        text: root.settings ? root.settings.exportDirectoryStatus : ""
                        color: root.settings && root.settings.exportDirectorySelected
                               ? Theme.signal : Theme.warningText
                        font.family: Theme.fontFamily
                        font.pixelSize: 12
                        wrapMode: Text.Wrap
                    }

                    RowLayout {
                        Layout.fillWidth: true
                        spacing: 8

                        AppButton {
                            Layout.fillWidth: true
                            text: root.platformStorage && root.platformStorage.busy ? "正在处理" : "选择导出目录"
                            iconText: "□"
                            variant: "primary"
                            enabled: root.platformStorage && !root.platformStorage.busy
                            onClicked: root.platformStorage.chooseExportDirectory()
                        }

                        AppButton {
                            visible: root.settings && root.settings.exportDirectorySelected
                            text: "清除"
                            variant: "ghost"
                            compact: true
                            onClicked: root.settings.clearExportDirectory()
                        }
                    }

                    AppButton {
                        visible: root.settings && root.settings.exportDirectorySelected
                        Layout.fillWidth: true
                        text: "打开导出目录"
                        variant: "secondary"
                        compact: true
                        onClicked: root.platformStorage.openDirectory(root.settings.exportDirectoryUri)
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

            SectionTitle { text: "工具诊断" }

            InlineNotice {
                Layout.fillWidth: true
                visible: root.tools && !root.tools.ready && !root.tools.checking
                tone: "warning"
                title: "下载工具需要处理"
                body: root.mobilePlatform
                      ? "Android 不依赖系统 PATH；请将匹配设备 ABI 的工具放入应用运行时目录，或设置自定义路径。"
                      : "设置自定义路径，或将 yt-dlp、FFmpeg 和 FFprobe 加入系统 PATH。"
            }

            ToolStatusRow {
                Layout.fillWidth: true
                displayName: "yt-dlp"
                available: root.tools ? root.tools.ytDlpAvailable : false
                checking: root.tools ? root.tools.checking : false
                version: root.tools ? root.tools.ytDlpVersion : ""
                path: root.tools ? root.tools.ytDlpPath : ""
                customPath: root.tools ? root.tools.ytDlpCustomPath : ""
                statusText: root.tools ? root.tools.ytDlpStatus : ""
                onPathSubmitted: function (path) { root.settings.ytDlpPath = path }
                onClearRequested: root.settings.ytDlpPath = ""
            }

            ToolStatusRow {
                Layout.fillWidth: true
                displayName: "FFmpeg"
                available: root.tools ? root.tools.ffmpegAvailable : false
                checking: root.tools ? root.tools.checking : false
                version: root.tools ? root.tools.ffmpegVersion : ""
                path: root.tools ? root.tools.ffmpegPath : ""
                customPath: root.tools ? root.tools.ffmpegCustomPath : ""
                statusText: root.tools ? root.tools.ffmpegStatus : ""
                onPathSubmitted: function (path) { root.settings.ffmpegPath = path }
                onClearRequested: root.settings.ffmpegPath = ""
            }

            ToolStatusRow {
                visible: !root.mobilePlatform
                Layout.fillWidth: true
                displayName: "FFprobe"
                available: root.tools ? root.tools.ffprobeAvailable : false
                checking: root.tools ? root.tools.checking : false
                version: root.tools ? root.tools.ffprobeVersion : ""
                path: root.tools ? root.tools.ffprobePath : ""
                customPath: root.tools ? root.tools.ffprobeCustomPath : ""
                statusText: root.tools ? root.tools.ffprobeStatus : ""
                onPathSubmitted: function (path) { root.tools.setCustomPath("ffprobe", path) }
                onClearRequested: root.tools.clearCustomPath("ffprobe")
            }

            AppButton {
                Layout.alignment: root.compact ? Qt.AlignHCenter : Qt.AlignLeft
                text: root.tools && root.tools.checking ? "正在检测" : "重新检测工具"
                iconText: "⟳"
                variant: "ghost"
                compact: true
                enabled: root.tools && !root.tools.checking
                onClicked: root.tools.refresh()
            }

            SectionTitle { text: "默认行为" }

            Rectangle {
                Layout.fillWidth: true
                implicitHeight: behaviorColumn.implicitHeight + 28
                radius: Theme.radiusPanel
                color: Theme.surface
                border.width: 1
                border.color: Theme.border

                ColumnLayout {
                    id: behaviorColumn
                    anchors.fill: parent
                    anchors.margins: 14
                    spacing: 12

                    SettingChoice {
                        label: "输出格式"
                        model: ["MP4 视频", "MP3 音频"]
                        currentIndex: root.settings && root.settings.defaultOutputFormat === "mp3" ? 1 : 0
                        onActivated: function (index) { root.settings.defaultOutputFormat = index === 1 ? "mp3" : "mp4" }
                    }

                    SettingChoice {
                        label: "清晰度策略"
                        model: ["优先最高质量", "优先兼容性"]
                        currentIndex: root.settings && root.settings.defaultFormatStrategy === "compatible" ? 1 : 0
                        onActivated: function (index) { root.settings.defaultFormatStrategy = index === 1 ? "compatible" : "best" }
                    }

                    SettingChoice {
                        label: "界面语言"
                        model: ["跟随系统", "简体中文", "English"]
                        currentIndex: root.settings && root.settings.language === "zh-cn" ? 1 : (root.settings && root.settings.language === "en" ? 2 : 0)
                        onActivated: function (index) { root.settings.language = index === 1 ? "zh-cn" : (index === 2 ? "en" : "system") }
                    }

                    SettingChoice {
                        label: "界面主题"
                        model: ["浅色", "深色"]
                        currentIndex: root.settings && root.settings.theme === "dark" ? 1 : 0
                        onActivated: function (index) { root.settings.theme = index === 1 ? "dark" : "light" }
                    }
                }
            }

            RowLayout {
                Layout.fillWidth: true
                Layout.topMargin: 2

                Label {
                    Layout.fillWidth: true
                    text: root.controller ? "Video Downloader  " + root.controller.qtVersion : ""
                    color: Theme.subtle
                    font.family: Theme.monoFamily
                    font.pixelSize: 11
                }

                AppButton {
                    text: "恢复默认设置"
                    variant: "ghost"
                    compact: true
                    onClicked: root.settings.reset()
                }
            }

            Label {
                Layout.fillWidth: true
                text: "仅处理你有权保存的非 DRM 内容。"
                color: Theme.subtle
                font.family: Theme.fontFamily
                font.pixelSize: 11
                horizontalAlignment: Text.AlignHCenter
                bottomPadding: 12
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

    component SettingChoice: RowLayout {
        property string label: ""
        property alias model: choice.model
        property alias currentIndex: choice.currentIndex
        signal activated(int index)
        Layout.fillWidth: true
        spacing: 12

        Label {
            Layout.fillWidth: true
            text: parent.label
            color: Theme.text
            font.family: Theme.fontFamily
            font.pixelSize: 13
        }

        ComboBox {
            id: choice
            Layout.preferredWidth: root.compact ? 156 : 190
            font.family: Theme.fontFamily
            font.pixelSize: 13

            contentItem: Text {
                leftPadding: 12
                rightPadding: 30
                text: choice.displayText
                color: Theme.text
                font: choice.font
                verticalAlignment: Text.AlignVCenter
                elide: Text.ElideRight
            }

            background: Rectangle {
                radius: Theme.radiusSmall
                color: Theme.background
                border.width: choice.visualFocus ? 2 : 1
                border.color: choice.visualFocus ? Theme.accent : Theme.border
            }

            onActivated: function (index) { parent.activated(index) }
        }
    }
}
