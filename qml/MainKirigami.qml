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
        return 0
    }

    function navigate(page) {
        window.currentPage = page === "queue" ? "new" : page
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
        if (compactSettingsDrawer && compactSettingsDrawer.opened) {
            compactSettingsDrawer.close()
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

    pageStack.globalToolBar.style: Kirigami.ApplicationHeaderStyle.None

    pageStack.initialPage: Kirigami.Page {
        id: workbenchPage
        title: "下载工作台"
        padding: 0
        background: Rectangle {
            color: Theme.background
        }

        ColumnLayout {
            anchors.fill: parent
            spacing: 0

            MobileHeader {
                visible: window.mobilePlatform || window.narrowDesktop
                onMenuClicked: compactSettingsDrawer.open()
            }

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
                            text: window.toolLocator.checking ? "正在初始化下载引擎" : "下载引擎尚未就绪"
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
                    }
                }

                ActivityPanel {
                    visible: window.wideWidth
                    Layout.preferredWidth: visible ? 312 : 0
                    Layout.topMargin: visible ? Theme.pageTop : 0
                    Layout.rightMargin: visible ? 18 : 0
                    Layout.bottomMargin: visible ? 18 : 0
                    queue: window.downloadQueue
                }
            }
        }
    }

    MobileSettingsDrawer {
        id: compactSettingsDrawer
        enabled: window.mobilePlatform || window.narrowDesktop
        settings: window.appSettings
        controller: window.appController
        platformStorage: window.platformStorage
    }
}
