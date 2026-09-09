import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import ReClip

ApplicationWindow {
    id: window

    property string currentPage: "new"
    property string pendingExternalUrl: ""
    readonly property bool mobilePlatform: Qt.platform.os === "android" || Qt.platform.os === "ios"
    readonly property bool compactWidth: mobilePlatform || width < 700
    readonly property bool wideWidth: !mobilePlatform && width >= 1060
    readonly property var appController: controller
    readonly property var appSettings: settings
    readonly property var toolLocator: tools
    readonly property var platformStorage: storage
    readonly property var mediaInspector: inspector
    readonly property var downloadManager: downloads
    readonly property var downloadQueue: queue

    width: 1200
    height: 780
    minimumWidth: mobilePlatform ? 0 : 560
    minimumHeight: mobilePlatform ? 0 : 560
    visible: true
    title: controller.productName
    color: Theme.background

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

    function consumeIncomingUrl() {
        if (controller.incomingUrl.length === 0) {
            return
        }

        window.pendingExternalUrl = controller.incomingUrl
        window.currentPage = "new"
        controller.clearIncomingUrl()
    }

    function handleBackAction() {
        if (window.currentPage !== "new") {
            window.currentPage = "new"
            return true
        }
        return false
    }

    // Android delivers the system back action as a window close request on
    // some Qt/Android combinations instead of a Qt.Key_Back event.
    onClosing: function (event) {
        if (window.mobilePlatform && window.handleBackAction()) {
            event.accepted = false
        }
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
    palette.highlight: Theme.accent
    palette.highlightedText: Theme.accentText

    AppController {
        id: controller
    }

    AppSettings {
        id: settings
    }

    PlatformStorage {
        id: storage
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
        exportDirectoryUri: settings.exportDirectoryUri
        platformStorage: window.platformStorage
    }

    DownloadQueue {
        id: queue
        ytDlpPath: tools.ytDlpPath
        ffmpegPath: tools.ffmpegPath
        downloadDirectory: settings.downloadDirectory
        exportDirectoryUri: settings.exportDirectoryUri
        platformStorage: window.platformStorage
    }

    Timer {
        id: notificationRetryTimer
        interval: 250
        repeat: true
        running: window.mobilePlatform

        onTriggered: {
            var taskId = window.downloadQueue.consumeAndroidNotificationRetry()
            if (taskId.length === 0) {
                return
            }
            window.downloadQueue.retryTask(taskId)
            stop()
        }
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

    Connections {
        target: platformStorage

        function onExportDirectorySelected(uri, label) {
            settings.setExportDirectory(uri, label)
        }
    }

    Connections {
        target: controller

        function onIncomingUrlChanged() {
            window.consumeIncomingUrl()
        }
    }

    Component.onCompleted: window.consumeIncomingUrl()

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
                    Layout.preferredHeight: 64
                    color: Theme.surface

                    Rectangle {
                        anchors.left: parent.left
                        anchors.right: parent.right
                        anchors.bottom: parent.bottom
                        height: 1
                        color: Theme.border
                    }

                    RowLayout {
                        anchors.fill: parent
                        anchors.leftMargin: 24
                        anchors.rightMargin: 24
                        spacing: 14

                        ColumnLayout {
                            Layout.fillWidth: true
                            spacing: 2

                            Label {
                                text: window.currentPage === "new" ? "新建下载" : (window.currentPage === "queue" ? "下载队列" : "设置")
                                color: Theme.text
                                font.family: Theme.fontFamily
                                font.pixelSize: 20
                                font.weight: Font.DemiBold
                                font.letterSpacing: 0.2
                            }

                            Label {
                                text: window.currentPage === "new" ? "粘贴链接，快速保存媒体"
                                      : (window.currentPage === "queue" ? window.downloadQueue.statusText : "让下载流程保持顺手")
                                color: Theme.muted
                                font.family: Theme.fontFamily
                                font.pixelSize: 12
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
                        id: desktopNewDownloadPage
                        controller: window.appController
                        settings: window.appSettings
                        tools: window.toolLocator
                        inspector: window.mediaInspector
                        downloads: window.downloadManager
                        queue: window.downloadQueue
                        initialUrl: window.pendingExternalUrl
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
                        platformStorage: window.platformStorage
                    }
                }
            }

            ActivityPanel {
                visible: window.wideWidth && window.currentPage !== "settings"
                Layout.preferredWidth: visible ? 300 : 0
                queue: window.downloadQueue
                onOpenQueue: window.navigate("queue")
            }
        }
    }

    Component {
        id: iosSettingsPage

        IosSettingsPage {
            settings: window.appSettings
            controller: window.appController
        }
    }

    Component {
        id: mobileSettingsPage

        SettingsPage {
            settings: window.appSettings
            tools: window.toolLocator
            controller: window.appController
            platformStorage: window.platformStorage
        }
    }

    Component {
        id: mobileShell

        ColumnLayout {
            anchors.fill: parent
            spacing: 0

            Rectangle {
                Layout.fillWidth: true
                Layout.preferredHeight: 76
                color: Theme.background

                RowLayout {
                    anchors.fill: parent
                    anchors.leftMargin: 20
                    anchors.rightMargin: 16
                    anchors.topMargin: 10
                    anchors.bottomMargin: 8
                    spacing: 12

                    ColumnLayout {
                        Layout.fillWidth: true
                        spacing: 1

                        Label {
                            text: window.currentPage === "new" ? "新建下载"
                                  : (window.currentPage === "queue" ? "下载队列" : "设置")
                            color: Theme.text
                            font.family: Theme.fontFamily
                            font.pixelSize: 26
                            font.weight: Font.Medium
                        }

                        Label {
                            text: window.appController.productName
                            color: Theme.muted
                            font.family: Theme.fontFamily
                            font.pixelSize: 11
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
                    id: mobileNewDownloadPage
                    controller: window.appController
                    settings: window.appSettings
                    tools: window.toolLocator
                    inspector: window.mediaInspector
                    downloads: window.downloadManager
                    queue: window.downloadQueue
                    initialUrl: window.pendingExternalUrl
                    onOpenQueue: window.navigate("queue")
                    onOpenTools: window.navigate("settings")
                }
                QueuePage {
                    queue: window.downloadQueue
                }

                Loader {
                    Layout.fillWidth: true
                    Layout.fillHeight: true
                    sourceComponent: Qt.platform.os === "ios" ? iosSettingsPage : mobileSettingsPage
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
