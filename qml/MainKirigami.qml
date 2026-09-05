import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import org.kde.kirigami as Kirigami
import ReClip

Kirigami.ApplicationWindow {
    id: window

    visible: true
    width: 1200
    height: 780
    minimumWidth: 560
    minimumHeight: 560
    title: controller.productName
    color: Theme.background

    property string currentPage: "new"
    readonly property bool compactWidth: width < 700
    readonly property bool wideWidth: width >= 1060
    readonly property var appController: controller
    readonly property var appSettings: settings
    readonly property var toolLocator: tools
    readonly property var mediaInspector: inspector
    readonly property var downloadManager: downloads
    readonly property var downloadQueue: queue

    function pageIndex() {
        if (currentPage === "queue") {
            return 1
        }
        if (currentPage === "settings") {
            return 2
        }
        return 0
    }

    function navigate(page) {
        window.currentPage = page
        navigationDrawer.close()
    }

    Binding {
        target: Theme
        property: "darkMode"
        value: settings.theme === "dark"
    }

    palette.window: Theme.background
    palette.windowText: Theme.text
    palette.base: Theme.surface
    palette.alternateBase: Theme.surfaceAlt
    palette.text: Theme.text
    palette.button: Theme.surface
    palette.buttonText: Theme.text
    palette.highlight: Theme.violet
    palette.highlightedText: "#FFFFFF"

    AppController {
        id: controller
    }

    AppSettings {
        id: settings
    }

    ToolLocator {
        id: tools

        Component.onCompleted: refresh()
    }

    MediaInspector {
        id: inspector
        ytDlpPath: tools.ytDlpPath
    }

    DownloadManager {
        id: downloads
        ytDlpPath: tools.ytDlpPath
        ffmpegPath: tools.ffmpegPath
        downloadDirectory: settings.downloadDirectory
        outputFormat: settings.defaultOutputFormat
    }

    DownloadQueue {
        id: queue
        ytDlpPath: tools.ytDlpPath
        ffmpegPath: tools.ffmpegPath
        downloadDirectory: settings.downloadDirectory
    }

    Connections {
        target: settings

        function onYtDlpPathChanged() {
            tools.refresh()
        }

        function onFfmpegPathChanged() {
            tools.refresh()
        }

        function onDefaultOutputFormatChanged() {
            downloads.outputFormat = settings.defaultOutputFormat
        }
    }

    globalDrawer: Kirigami.GlobalDrawer {
        id: navigationDrawer
        title: window.appController.productName
        isMenu: false
        actions: [
            Kirigami.Action {
                text: "新建下载"
                icon.name: "list-add"
                checkable: true
                checked: window.currentPage === "new"
                onTriggered: window.navigate("new")
            },
            Kirigami.Action {
                text: "下载队列"
                icon.name: "view-list-details"
                checkable: true
                checked: window.currentPage === "queue"
                onTriggered: window.navigate("queue")
            },
            Kirigami.Action {
                text: "设置"
                icon.name: "settings-configure"
                checkable: true
                checked: window.currentPage === "settings"
                onTriggered: window.navigate("settings")
            }
        ]

        Label {
            Layout.fillWidth: true
            text: window.toolLocator.ready ? "yt-dlp / FFmpeg 已就绪" : "需要检查下载工具"
            color: window.toolLocator.ready ? Theme.signal : Theme.warningText
            font.family: Theme.fontFamily
            font.pixelSize: 11
            wrapMode: Text.Wrap
            padding: 16
        }
    }

    pageStack.globalToolBar.style: Kirigami.ApplicationHeaderStyle.Titles

    pageStack.initialPage: Kirigami.Page {
        id: workbenchPage
        title: window.currentPage === "new" ? "新建下载"
              : (window.currentPage === "queue" ? "下载队列" : "设置")
        padding: 0

        ColumnLayout {
            anchors.fill: parent
            spacing: 0

            Rectangle {
                Layout.fillWidth: true
                Layout.preferredHeight: 52
                color: Theme.background
                border.width: 1
                border.color: Theme.border

                RowLayout {
                    anchors.fill: parent
                    anchors.leftMargin: 20
                    anchors.rightMargin: 20
                    spacing: 12

                    Label {
                        Layout.fillWidth: true
                        text: window.currentPage === "new" ? "粘贴链接，确认媒体信息后选择输出格式"
                              : (window.currentPage === "queue" ? window.downloadQueue.statusText : "让下载流程保持顺手")
                        color: Theme.muted
                        font.family: Theme.fontFamily
                        font.pixelSize: 11
                        elide: Text.ElideRight
                    }

                    StatusPill {
                        state: window.toolLocator.checking ? "downloading" : (window.toolLocator.ready ? "completed" : "failed")
                        label: window.toolLocator.checking ? "检测中" : (window.toolLocator.ready ? "工具已就绪" : "需要处理")
                        compact: true
                    }
                }
            }

            RowLayout {
                Layout.fillWidth: true
                Layout.fillHeight: true
                spacing: 0

                StackLayout {
                    id: pages
                    Layout.fillWidth: true
                    Layout.fillHeight: true
                    currentIndex: window.pageIndex()

                    NewDownloadPage {
                        controller: window.appController
                        settings: window.appSettings
                        tools: window.toolLocator
                        inspector: window.mediaInspector
                        downloads: window.downloadManager
                        queue: window.downloadQueue
                        onOpenQueue: window.navigate("queue")
                        onOpenTools: window.navigate("settings")
                    }

                    QueuePage {
                        queue: window.downloadQueue
                    }

                    SettingsPage {
                        settings: window.appSettings
                        tools: window.toolLocator
                        controller: window.appController
                    }
                }

                ActivityPanel {
                    visible: window.wideWidth
                    Layout.preferredWidth: window.wideWidth ? 320 : 0
                    queue: window.downloadQueue
                    onOpenQueue: window.navigate("queue")
                }
            }
        }
    }
}
