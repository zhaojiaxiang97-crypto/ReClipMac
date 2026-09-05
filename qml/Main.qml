import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import ReClip

ApplicationWindow {
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

    Component {
        id: desktopShell

        RowLayout {
            anchors.fill: parent
            spacing: 0

            DesktopSidebar {
                currentPage: window.currentPage
                toolsReady: window.toolLocator.ready
                productName: window.appController.productName
                onNavigate: function (page) { window.navigate(page) }
            }

            ColumnLayout {
                Layout.fillWidth: true
                Layout.fillHeight: true
                spacing: 0

                Rectangle {
                    Layout.fillWidth: true
                    Layout.preferredHeight: 68
                    color: Theme.background
                    border.width: 1
                    border.color: Theme.border

                    RowLayout {
                        anchors.fill: parent
                        anchors.leftMargin: 28
                        anchors.rightMargin: 28
                        spacing: 14

                        ColumnLayout {
                            Layout.fillWidth: true
                            spacing: 2

                            Label {
                                text: window.currentPage === "new" ? "新建下载" : (window.currentPage === "queue" ? "下载队列" : "设置")
                                color: Theme.text
                                font.family: Theme.fontFamily
                                font.pixelSize: 18
                                font.weight: Font.DemiBold
                            }

                            Label {
                                text: window.currentPage === "new" ? "Signal Desk  ·  把链接变成文件"
                                      : (window.currentPage === "queue" ? window.downloadQueue.statusText : "让下载流程保持顺手")
                                color: Theme.muted
                                font.family: Theme.fontFamily
                                font.pixelSize: 11
                            }
                        }

                        StatusPill {
                            state: window.toolLocator.checking ? "downloading" : (window.toolLocator.ready ? "completed" : "failed")
                            label: window.toolLocator.checking ? "检测中" : (window.toolLocator.ready ? "工具已就绪" : "需要处理")
                            compact: true
                        }

                        Label {
                            visible: window.currentPage === "new"
                            text: "Ctrl / ⌘ + Enter 解析"
                            color: Theme.subtle
                            font.family: Theme.monoFamily
                            font.pixelSize: 10
                        }
                    }
                }

                StackLayout {
                    id: desktopPages
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
            }

            ActivityPanel {
                visible: window.wideWidth
                Layout.preferredWidth: window.wideWidth ? 320 : 0
                queue: window.downloadQueue
                onOpenQueue: window.navigate("queue")
            }
        }
    }

    Component {
        id: mobileShell

        ColumnLayout {
            anchors.fill: parent
            spacing: 0

            Rectangle {
                Layout.fillWidth: true
                Layout.preferredHeight: 64
                color: Theme.surface
                border.width: 1
                border.color: Theme.border

                RowLayout {
                    anchors.fill: parent
                    anchors.leftMargin: 16
                    anchors.rightMargin: 12

                    Rectangle {
                        Layout.preferredWidth: 30
                        Layout.preferredHeight: 30
                        radius: 9
                        color: Theme.violet

                        Text {
                            anchors.centerIn: parent
                            text: "⌁"
                            color: "#FFFFFF"
                            font.family: Theme.fontFamily
                            font.pixelSize: 18
                            font.weight: Font.Bold
                        }
                    }

                    ColumnLayout {
                        Layout.fillWidth: true
                        spacing: 0

                        Label {
                            text: window.appController.productName
                            color: Theme.text
                            font.family: Theme.fontFamily
                            font.pixelSize: 15
                            font.weight: Font.Bold
                        }

                        Label {
                            text: window.currentPage === "new" ? "新建下载" : (window.currentPage === "queue" ? "下载队列" : "设置")
                            color: Theme.muted
                            font.family: Theme.fontFamily
                            font.pixelSize: 10
                        }
                    }

                    StatusPill {
                        state: window.toolLocator.checking ? "downloading" : (window.toolLocator.ready ? "completed" : "failed")
                        label: window.toolLocator.checking ? "检测中" : (window.toolLocator.ready ? "就绪" : "检查")
                        compact: true
                    }
                }
            }

            StackLayout {
                id: mobilePages
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

            MobileBottomBar {
                currentPage: window.currentPage
                onNavigate: function (page) { window.navigate(page) }
            }
        }
    }

    Loader {
        anchors.fill: parent
        sourceComponent: window.compactWidth ? mobileShell : desktopShell
    }
}
