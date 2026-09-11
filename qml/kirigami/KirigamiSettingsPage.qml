import QtQuick
import QtQuick.Controls
import QtQuick.Dialogs
import QtQuick.Layouts
import org.kde.kirigami as Kirigami
import org.kde.kirigami.layouts as KirigamiLayouts
import ReClip

Kirigami.ScrollablePage {
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
                text: "调整下载目录、工具路径和默认行为。"
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
                    text: root.settings ? root.settings.exportDirectoryStatus : ""
                    color: root.settings && root.settings.exportDirectorySelected ? Theme.signal : Theme.warningText
                    font.family: Theme.fontFamily
                    font.pixelSize: 12
                    wrapMode: Text.Wrap
                }

                RowLayout {
                    Layout.fillWidth: true

                    Button {
                        Layout.fillWidth: true
                        text: root.platformStorage && root.platformStorage.busy ? "正在处理" : "选择导出目录"
                        icon.name: "folder-open"
                        enabled: root.platformStorage && !root.platformStorage.busy
                        onClicked: root.platformStorage.chooseExportDirectory()
                    }

                    Button {
                        visible: root.settings && root.settings.exportDirectorySelected
                        text: "清除"
                        onClicked: root.settings.clearExportDirectory()
                    }
                }

                Button {
                    visible: root.settings && root.settings.exportDirectorySelected
                    Layout.fillWidth: true
                    text: "打开导出目录"
                    icon.name: "folder-open"
                    onClicked: root.platformStorage.openDirectory(root.settings.exportDirectoryUri)
                }

                Kirigami.InlineMessage {
                    Layout.fillWidth: true
                    visible: root.platformStorage && root.platformStorage.lastError.length > 0
                    type: Kirigami.MessageType.Error
                    text: root.platformStorage ? root.platformStorage.lastError : ""
                }
            }
        }

        Kirigami.Card {
            Layout.fillWidth: true

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
                    text: "工具诊断"
                    color: Theme.text
                    font.family: Theme.fontFamily
                }

                Kirigami.InlineMessage {
                    Layout.fillWidth: true
                    visible: root.tools && !root.tools.ready && !root.tools.checking
                    type: Kirigami.MessageType.Warning
                    text: root.mobilePlatform
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

                Kirigami.ActionToolBar {
                    actions: [
                        Kirigami.Action {
                            text: root.tools && root.tools.checking ? "正在检测" : "重新检测工具"
                            icon.name: "view-refresh"
                            enabled: root.tools && !root.tools.checking
                            onTriggered: root.tools.refresh()
                        }
                    ]
                }
            }
        }

        Kirigami.Card {
            Layout.fillWidth: true

            background: Rectangle {
                color: Theme.surface
                radius: Theme.radiusPanel
                border.width: 1
                border.color: Theme.border
            }

            contentItem: KirigamiLayouts.FormLayout {
                width: parent ? parent.width : 0
                wideMode: !root.compact

                AppSelect {
                    Kirigami.FormData.label: "输出格式"
                    model: ["MP4 视频", "MP3 音频"]
                    currentIndex: root.settings && root.settings.defaultOutputFormat === "mp3" ? 1 : 0
                    onActivated: function (index) {
                        if (root.settings) {
                            root.settings.defaultOutputFormat = index === 1 ? "mp3" : "mp4"
                        }
                    }
                }

                AppSelect {
                    Kirigami.FormData.label: "清晰度策略"
                    model: ["优先最高质量", "优先兼容性"]
                    currentIndex: root.settings && root.settings.defaultFormatStrategy === "compatible" ? 1 : 0
                    onActivated: function (index) {
                        if (root.settings) {
                            root.settings.defaultFormatStrategy = index === 1 ? "compatible" : "best"
                        }
                    }
                }

                AppSelect {
                    Kirigami.FormData.label: "界面语言"
                    model: ["跟随系统", "简体中文", "English"]
                    currentIndex: root.settings && root.settings.language === "zh-cn" ? 1 : (root.settings && root.settings.language === "en" ? 2 : 0)
                    onActivated: function (index) {
                        if (root.settings) {
                            root.settings.language = index === 1 ? "zh-cn" : (index === 2 ? "en" : "system")
                        }
                    }
                }

                AppSelect {
                    Kirigami.FormData.label: "界面主题"
                    model: ["浅色", "深色"]
                    currentIndex: root.settings && root.settings.theme === "dark" ? 1 : 0
                    onActivated: function (index) {
                        if (root.settings) {
                            root.settings.theme = index === 1 ? "dark" : "light"
                        }
                    }
                }
            }
        }

    }
}
