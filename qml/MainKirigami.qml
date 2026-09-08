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

    // Keep Kirigami adaptive while using the shared platform-aware Theme:
    // light and neutral on Windows, Graphite Rose on Android.
    Kirigami.Theme.inherit: false
    Kirigami.Theme.colorSet: Kirigami.Theme.Window
    Kirigami.Theme.backgroundColor: Theme.background
    Kirigami.Theme.textColor: Theme.text
    Kirigami.Theme.highlightColor: Theme.accent
    Kirigami.Theme.highlightedTextColor: Theme.accentText
    Kirigami.Theme.positiveTextColor: Theme.signal
    Kirigami.Theme.neutralTextColor: Theme.warningText
    Kirigami.Theme.negativeTextColor: Theme.danger

    property string currentPage: "new"
    property string pendingExternalUrl: ""
    readonly property bool mobilePlatform: Qt.platform.os === "android" || Qt.platform.os === "ios"
    readonly property bool compactWidth: mobilePlatform || width < 700
    readonly property bool narrowDesktop: !mobilePlatform && width < 1060
    readonly property bool wideWidth: !mobilePlatform && width >= 1060
    readonly property var appController: controller
    readonly property var appSettings: settings
    readonly property var toolLocator: tools
    readonly property var platformStorage: storage
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

    function consumeIncomingUrl() {
        if (controller.incomingUrl.length === 0) {
            return
        }

        window.pendingExternalUrl = controller.incomingUrl
        window.currentPage = "new"
        controller.clearIncomingUrl()
    }

    function handleBackAction() {
        if (navigationDrawer && navigationDrawer.opened) {
            navigationDrawer.close()
            return true
        }
        if (window.currentPage !== "new") {
            window.currentPage = "new"
            return true
        }
        return false
    }

    Keys.onReleased: function (event) {
        if (event.key === Qt.Key_Back && window.handleBackAction()) {
            event.accepted = true
        }
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

    globalDrawer: Kirigami.GlobalDrawer {
        id: navigationDrawer
        visible: !window.narrowDesktop
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

    // A narrow desktop window has enough width for a real page switcher but
    // not enough room for the full drawer + activity workspace. Kirigami's
    // tab bar keeps the navigation reachable without duplicating page state.
    footer: Kirigami.NavigationTabBar {
        id: narrowNavigation
        visible: window.narrowDesktop
        height: visible ? implicitHeight : 0
        Accessible.name: "主要页面导航"

        Kirigami.Theme.inherit: false
        Kirigami.Theme.colorSet: Kirigami.Theme.Window
        Kirigami.Theme.backgroundColor: Theme.surface
        Kirigami.Theme.textColor: Theme.text
        Kirigami.Theme.highlightColor: Theme.accent

        background: Rectangle {
            color: Theme.surface
            border.width: 1
            border.color: Theme.border
        }

        actions: [
            Kirigami.Action {
                text: "新建下载"
                icon.name: "list-add"
                checked: window.currentPage === "new"
                onTriggered: window.navigate("new")
            },
            Kirigami.Action {
                text: "下载队列"
                icon.name: "view-list-details"
                checked: window.currentPage === "queue"
                onTriggered: window.navigate("queue")
            },
            Kirigami.Action {
                text: "设置"
                icon.name: "settings-configure"
                checked: window.currentPage === "settings"
                onTriggered: window.navigate("settings")
            }
        ]
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
                        spacing: 12

                            Label {
                                Layout.fillWidth: true
                                text: window.currentPage === "new" ? "粘贴链接，确认媒体信息后选择输出格式"
                                      : (window.currentPage === "queue" ? window.downloadQueue.statusText : "让下载流程保持顺手")
                                color: Theme.muted
                                font.family: Theme.fontFamily
                                font.pixelSize: 12
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

                    KirigamiNewDownloadPage {
                        id: kirigamiNewDownloadPage
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

                    KirigamiQueuePage {
                        queue: window.downloadQueue
                        onOpenNew: window.navigate("new")
                    }

                    KirigamiSettingsPage {
                        settings: window.appSettings
                        tools: window.toolLocator
                        controller: window.appController
                        platformStorage: window.platformStorage
                    }
                }

                ActivityPanel {
                    visible: window.wideWidth
                    Layout.preferredWidth: window.wideWidth ? 300 : 0
                    queue: window.downloadQueue
                    onOpenQueue: window.navigate("queue")
                }
            }
        }
    }
}
