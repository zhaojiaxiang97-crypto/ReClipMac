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
    background: Rectangle {
        color: Theme.background
    }

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
        return currentPage === "settings" ? 1 : 0
    }

    function navigate(page) {
        window.currentPage = page === "queue" ? "new" : page
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
        visible: window.mobilePlatform
        enabled: window.mobilePlatform
        handleVisible: window.mobilePlatform
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
    footer: MobileBottomBar {
        id: narrowNavigation
        visible: window.narrowDesktop
        height: visible ? implicitHeight : 0
        currentPage: window.currentPage
        onNavigate: page => window.navigate(page)
    }

    pageStack.globalToolBar.style: Kirigami.ApplicationHeaderStyle.None

    pageStack.initialPage: Kirigami.Page {
        id: workbenchPage
        title: window.currentPage === "settings" ? "设置" : "下载工作台"
        padding: 0
        background: Rectangle {
            color: Theme.background
        }

        ColumnLayout {
            anchors.fill: parent
            spacing: 0

            Rectangle {
                visible: window.toolLocator.checking || !window.toolLocator.ready
                Layout.fillWidth: true
                Layout.preferredHeight: visible ? 54 : 0
                color: Theme.background

                    RowLayout {
                        anchors.fill: parent
                        anchors.leftMargin: Theme.pageGutter
                        anchors.rightMargin: Theme.pageGutter
                        spacing: 12

                        Label {
                            Layout.fillWidth: true
                            text: window.toolLocator.checking ? "正在检查下载引擎" : "下载工具尚未就绪"
                            color: Theme.muted
                            font.family: Theme.fontFamily
                            font.pixelSize: 12
                            font.weight: Font.Medium
                            elide: Text.ElideRight
                        }

                }
            }

            RowLayout {
                Layout.fillWidth: true
                Layout.fillHeight: true
                spacing: 0

                DesktopSidebar {
                    visible: !window.mobilePlatform && !window.narrowDesktop
                    currentPage: window.currentPage
                    toolsReady: window.toolLocator.ready
                    productName: window.appController.productName
                    onNavigate: function (page) { window.navigate(page) }
                }

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
                        inlineQueue: !window.wideWidth
                        initialUrl: window.pendingExternalUrl
                        onOpenTools: window.navigate("settings")
                    }

                    KirigamiSettingsPage {
                        settings: window.appSettings
                        tools: window.toolLocator
                        controller: window.appController
                        platformStorage: window.platformStorage
                    }
                }

                ActivityPanel {
                    visible: window.wideWidth && window.currentPage !== "settings"
                    Layout.preferredWidth: visible ? 312 : 0
                    Layout.topMargin: visible ? Theme.pageTop : 0
                    Layout.rightMargin: visible ? 18 : 0
                    Layout.bottomMargin: visible ? 18 : 0
                    queue: window.downloadQueue
                }
            }
        }
    }
}
