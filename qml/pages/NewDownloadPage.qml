import QtQuick
import QtQuick.Controls
import QtQuick.Dialogs
import QtQuick.Layouts

Item {
    id: root

    property var controller: null
    property var settings: null
    property var tools: null
    property var inspector: null
    property var downloads: null
    property var queue: null
    property var platformStorage: null
    property bool compact: root.mobilePlatform
    property string initialUrl: ""
    readonly property bool mobilePlatform: Qt.platform.os === "android" || Qt.platform.os === "ios"
    implicitHeight: content.implicitHeight + content.y + (root.compact ? 12 : Theme.pageTop)

    signal openQueue()

    function startInspection() {
        var values = capture.text.trim().split(/[\s,]+/)
        if (values.length > 0 && values[0].length > 0) {
            inspector.inspect(values[0])
        }
    }

    function acceptExternalUrl(url) {
        var value = (url || "").trim()
        if (value.length === 0) {
            return
        }
        capture.text = value
        startInspection()
    }

    function openFolderDialog() {
        if (folderDialogLoader.item) {
            folderDialogLoader.item.open()
        }
    }

    onInitialUrlChanged: acceptExternalUrl(initialUrl)

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
            if (root.mobilePlatform && Qt.platform.os === "android") {
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
            y: root.compact ? 12 : Theme.pageTop
            spacing: root.compact ? 12 : Theme.pageSpacing

            RowLayout {
                Layout.fillWidth: true

                ColumnLayout {
                    Layout.fillWidth: true
                    spacing: 4

                    Label {
                        text: root.compact ? "欢迎使用" : "新建下载"
                        color: Theme.text
                        font.family: Theme.fontFamily
                        font.pixelSize: root.compact ? 28 : 30
                        font.weight: Font.DemiBold
                    }

                    Label {
                        text: root.compact ? "粘贴链接，解析并下载您喜欢的媒体内容。" : "粘贴媒体链接，解析并下载视频或音频"
                        color: Theme.muted
                        font.family: Theme.fontFamily
                        font.pixelSize: root.compact ? 13 : 15
                    }
                }

            }

            LinkCapture {
                id: capture
                Layout.fillWidth: true
                busy: inspector && inspector.inspecting

                onParseRequested: root.startInspection()
                onPasteRequested: {
                    if (capture.text.length > 0) {
                        root.startInspection()
                    }
                }
                onUrlsDropped: function (urls) {
                    capture.text = urls.join("\n")
                    root.startInspection()
                }
            }

            Rectangle {
                visible: !root.compact
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
                    spacing: 8

                    RowLayout {
                        Layout.fillWidth: true

                        ColumnLayout {
                            Layout.fillWidth: true
                            spacing: 2

                            Label {
                                text: "保存位置"
                                color: Theme.text
                                font.family: Theme.fontFamily
                                font.pixelSize: 15
                                font.weight: Font.DemiBold
                            }

                            Label {
                                text: "下载完成后会保存到此文件夹"
                                color: Theme.muted
                                font.family: Theme.fontFamily
                                font.pixelSize: 12
                            }
                        }

                        StatusPill {
                            state: root.settings && root.settings.downloadDirectoryValid ? "completed" : "failed"
                            label: root.settings ? root.settings.downloadDirectoryStatus : ""
                            compact: true
                        }
                    }

                    RowLayout {
                        Layout.fillWidth: true
                        spacing: 8

                        AppTextField {
                            id: directoryField
                            Layout.fillWidth: true
                            text: root.settings ? root.settings.downloadDirectory : ""
                            selectByMouse: true
                            font.family: Theme.monoFamily
                            font.pixelSize: 12
                            placeholderText: "下载文件夹"
                        }

                        AppButton {
                            text: "选择目录"
                            iconName: "folder"
                            variant: "secondary"
                            compact: true
                            onClicked: root.openFolderDialog()
                        }

                        AppButton {
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
                }
            }

            ActivityPanel {
                visible: !root.compact
                Layout.fillWidth: true
                queue: root.queue
                compact: root.compact
            }

            InlineNotice {
                Layout.fillWidth: true
                visible: tools && !tools.ready && !tools.checking
                tone: "warning"
                title: "下载引擎还没有准备好"
                body: "下载运行时尚未完成初始化，请稍后重新解析。"
            }

            ColumnLayout {
                visible: inspector && inspector.inspecting
                Layout.fillWidth: true
                spacing: 6

                Label {
                    Layout.fillWidth: true
                    text: "正在读取媒体信息"
                    color: Theme.muted
                    font.family: Theme.fontFamily
                    font.pixelSize: 12
                }

                SignalTrace {
                    Layout.fillWidth: true
                    Layout.preferredHeight: 8
                    implicitHeight: 8
                    indeterminate: true
                    showMarker: false
                    state: "inspecting"
                }
            }

            InlineNotice {
                Layout.fillWidth: true
                visible: inspector && inspector.state === "error"
                tone: "danger"
                title: "无法读取这个链接"
                body: inspector ? inspector.errorMessage : ""
                actionText: "重新解析"
                onActionTriggered: root.startInspection()
            }

            MediaPreview {
                Layout.fillWidth: true
                visible: inspector && inspector.hasResult
                inspector: root.inspector
                settings: root.settings
                compact: root.compact
                onDownloadRequested: function (format) {
                    if (Qt.platform.os === "ios") {
                        queue.addTaskWithTitle(inspector.sourceUrl, inspector.selectedFormatId,
                                               format, inspector.title)
                        queue.startAll()
                        root.openQueue()
                    } else {
                        downloads.startDownload(inspector.sourceUrl, inspector.selectedFormatId, format)
                    }
                }
                onQueueRequested: function (format) {
                    queue.addTaskWithTitle(inspector.sourceUrl, inspector.selectedFormatId,
                                           format, inspector.title)
                    if (root.compact) {
                        root.openQueue()
                    }
                }
            }

            Rectangle {
                id: mobilePreviewPlaceholder

                visible: Qt.platform.os === "android"
                         && root.inspector
                         && !root.inspector.hasResult
                         && !root.inspector.inspecting
                         && root.inspector.state !== "error"
                Layout.fillWidth: true
                implicitHeight: placeholderColumn.implicitHeight + 32
                radius: Theme.radiusPanel
                color: Theme.surface
                border.width: 1
                border.color: Theme.border

                ColumnLayout {
                    id: placeholderColumn
                    anchors.fill: parent
                    anchors.margins: 16
                    spacing: 12

                    RowLayout {
                        Layout.fillWidth: true
                        spacing: 10

                        Rectangle {
                            Layout.preferredWidth: 32
                            Layout.preferredHeight: 32
                            radius: width / 2
                            color: Theme.violetSurface

                            IconGlyph {
                                anchors.centerIn: parent
                                name: "video"
                                color: Theme.accent
                                size: 18
                            }
                        }

                        ColumnLayout {
                            Layout.fillWidth: true
                            spacing: 2

                            Label {
                                text: "媒体预览"
                                color: Theme.text
                                font.family: Theme.fontFamily
                                font.pixelSize: 17
                                font.weight: Font.DemiBold
                            }

                            Label {
                                text: "解析完成后将显示媒体信息"
                                color: Theme.muted
                                font.family: Theme.fontFamily
                                font.pixelSize: 12
                            }
                        }
                    }

                    RowLayout {
                        Layout.fillWidth: true
                        spacing: 12

                        Rectangle {
                            Layout.preferredWidth: Math.max(112, Math.min(128, root.width * 0.30))
                            Layout.preferredHeight: 150
                            Layout.alignment: Qt.AlignTop
                            radius: Theme.radiusControl
                            color: Theme.surfaceRaised
                            clip: true

                            Rectangle {
                                width: 48
                                height: 48
                                anchors.centerIn: parent
                                radius: width / 2
                                color: Qt.alpha(Theme.text, 0.18)

                                IconGlyph {
                                    anchors.centerIn: parent
                                    name: "play"
                                    color: Theme.text
                                    size: 22
                                }
                            }

                            Label {
                                anchors.horizontalCenter: parent.horizontalCenter
                                anchors.bottom: parent.bottom
                                anchors.bottomMargin: 12
                                text: "暂无预览"
                                color: Theme.muted
                                font.family: Theme.fontFamily
                                font.pixelSize: 12
                            }
                        }

                        ColumnLayout {
                            Layout.fillWidth: true
                            Layout.alignment: Qt.AlignTop
                            spacing: 6

                            Label {
                                text: "暂无媒体信息"
                                color: Theme.text
                                font.family: Theme.fontFamily
                                font.pixelSize: 16
                                font.weight: Font.DemiBold
                                elide: Text.ElideRight
                            }

                            Label {
                                Layout.fillWidth: true
                                text: "请先粘贴链接并解析"
                                color: Theme.muted
                                font.family: Theme.fontFamily
                                font.pixelSize: 12
                                elide: Text.ElideRight
                            }

                            GridLayout {
                                Layout.fillWidth: true
                                columns: 2
                                columnSpacing: 8
                                rowSpacing: 6

                                ColumnLayout {
                                    Layout.fillWidth: true
                                    spacing: 4

                                    Label {
                                        text: "格式"
                                        color: Theme.muted
                                        font.family: Theme.fontFamily
                                        font.pixelSize: 11
                                    }

                                    Rectangle {
                                        Layout.fillWidth: true
                                        Layout.preferredHeight: 44
                                        radius: Theme.radiusControl
                                        color: Theme.surfaceAlt
                                        border.width: 1
                                        border.color: Theme.border

                                        RowLayout {
                                            anchors.fill: parent
                                            anchors.leftMargin: 10
                                            anchors.rightMargin: 10

                                            Label {
                                                Layout.fillWidth: true
                                                text: "MP4"
                                                color: Theme.muted
                                                font.family: Theme.fontFamily
                                                font.pixelSize: 12
                                                elide: Text.ElideRight
                                            }

                                            Item {
                                                Layout.preferredWidth: 16
                                                Layout.preferredHeight: 16

                                                Rectangle {
                                                    x: 1
                                                    y: 6
                                                    width: 8
                                                    height: 2
                                                    radius: 1
                                                    rotation: 45
                                                    color: Theme.subtle
                                                }

                                                Rectangle {
                                                    x: 7
                                                    y: 6
                                                    width: 8
                                                    height: 2
                                                    radius: 1
                                                    rotation: -45
                                                    color: Theme.subtle
                                                }
                                            }
                                        }
                                    }
                                }

                                ColumnLayout {
                                    Layout.fillWidth: true
                                    spacing: 4

                                    Label {
                                        text: "画质"
                                        color: Theme.muted
                                        font.family: Theme.fontFamily
                                        font.pixelSize: 11
                                    }

                                    Rectangle {
                                        Layout.fillWidth: true
                                        Layout.preferredHeight: 44
                                        radius: Theme.radiusControl
                                        color: Theme.surfaceAlt
                                        border.width: 1
                                        border.color: Theme.border

                                        RowLayout {
                                            anchors.fill: parent
                                            anchors.leftMargin: 10
                                            anchors.rightMargin: 10

                                            Label {
                                                Layout.fillWidth: true
                                                text: "高清"
                                                color: Theme.muted
                                                font.family: Theme.fontFamily
                                                font.pixelSize: 12
                                                elide: Text.ElideRight
                                            }

                                            Item {
                                                Layout.preferredWidth: 16
                                                Layout.preferredHeight: 16

                                                Rectangle {
                                                    x: 1
                                                    y: 6
                                                    width: 8
                                                    height: 2
                                                    radius: 1
                                                    rotation: 45
                                                    color: Theme.subtle
                                                }

                                                Rectangle {
                                                    x: 7
                                                    y: 6
                                                    width: 8
                                                    height: 2
                                                    radius: 1
                                                    rotation: -45
                                                    color: Theme.subtle
                                                }
                                            }
                                        }
                                    }
                                }
                            }
                        }
                    }

                    RowLayout {
                        Layout.fillWidth: true
                        spacing: 8

                        AppButton {
                            Layout.fillWidth: true
                            Layout.minimumWidth: 0
                            text: "下载"
                            iconName: "download"
                            variant: "primary"
                            enabled: false
                        }

                        AppButton {
                            Layout.fillWidth: true
                            Layout.minimumWidth: 0
                            text: "加入队列"
                            iconName: "queue"
                            variant: "secondary"
                            enabled: false
                        }
                    }
                }
            }

            Rectangle {
                id: mobileLocationCard

                visible: Qt.platform.os === "android"
                Layout.fillWidth: true
                implicitHeight: locationColumn.implicitHeight + 32
                radius: Theme.radiusPanel
                color: Theme.surface
                border.width: 1
                border.color: Theme.border

                ColumnLayout {
                    id: locationColumn
                    anchors.fill: parent
                    anchors.margins: 16
                    spacing: 10

                    RowLayout {
                        Layout.fillWidth: true
                        spacing: 10

                        Rectangle {
                            Layout.preferredWidth: 32
                            Layout.preferredHeight: 32
                            radius: width / 2
                            color: Theme.signalSurface

                            IconGlyph {
                                anchors.centerIn: parent
                                name: "folder"
                                color: Theme.signal
                                size: 18
                            }
                        }

                        ColumnLayout {
                            Layout.fillWidth: true
                            spacing: 2

                            Label {
                                text: "保存位置"
                                color: Theme.text
                                font.family: Theme.fontFamily
                                font.pixelSize: 17
                                font.weight: Font.DemiBold
                            }

                            Label {
                                text: "下载的文件将保存到已设置的位置"
                                color: Theme.muted
                                font.family: Theme.fontFamily
                                font.pixelSize: 12
                                elide: Text.ElideRight
                            }
                        }
                    }

                    Rectangle {
                        Layout.fillWidth: true
                        Layout.preferredHeight: 46
                        radius: Theme.radiusControl
                        color: Theme.surfaceAlt
                        border.width: 1
                        border.color: Theme.border

                        RowLayout {
                            anchors.fill: parent
                            anchors.leftMargin: 10
                            anchors.rightMargin: 10
                            spacing: 10

                            Rectangle {
                                Layout.preferredWidth: 24
                                Layout.preferredHeight: 24
                                radius: width / 2
                                color: Theme.signalSurface

                                IconGlyph {
                                    anchors.centerIn: parent
                                    name: "check"
                                    color: Theme.signal
                                    size: 13
                                }
                            }

                            Label {
                                Layout.fillWidth: true
                                text: root.settings && root.settings.exportDirectorySelected
                                      ? "已设置保存位置"
                                      : "已使用系统默认位置"
                                color: root.settings && root.settings.exportDirectorySelected ? Theme.signal : Theme.muted
                                font.family: Theme.fontFamily
                                font.pixelSize: 13
                                elide: Text.ElideRight
                            }

                            Label {
                                text: "›"
                                color: Theme.text
                                font.family: Theme.fontFamily
                                font.pixelSize: 26
                                verticalAlignment: Text.AlignVCenter
                            }
                        }
                    }

                    AppButton {
                        Layout.fillWidth: true
                        Layout.minimumWidth: 0
                        text: root.platformStorage && root.platformStorage.busy ? "正在处理" : "设置保存位置"
                        iconName: "folder-open"
                        variant: "secondary"
                        enabled: root.platformStorage
                                 && root.platformStorage.canChooseExportDirectory
                                 && !root.platformStorage.busy
                        onClicked: root.platformStorage.chooseExportDirectory()
                    }

                    InlineNotice {
                        Layout.fillWidth: true
                        visible: root.platformStorage && root.platformStorage.lastError.length > 0
                        tone: "danger"
                        title: "保存位置不可用"
                        body: root.platformStorage ? root.platformStorage.lastError : ""
                    }
                }
            }

            DownloadStatusPanel {
                Layout.fillWidth: true
                downloads: root.downloads
                compact: root.compact
            }

            ColumnLayout {
                visible: root.compact && queue && queue.tasks.length > 0
                Layout.fillWidth: true
                spacing: 10

                RowLayout {
                    Layout.fillWidth: true

                    Label {
                        text: "最近任务"
                        color: Theme.text
                        font.family: Theme.fontFamily
                        font.pixelSize: 17
                        font.weight: Font.DemiBold
                    }

                    Item { Layout.fillWidth: true }

                    AppButton {
                        text: "查看全部"
                        variant: "ghost"
                        compact: true
                        onClicked: root.openQueue()
                    }
                }

                Repeater {
                    model: queue ? Math.min(queue.tasks.length, 2) : 0

                    delegate: DownloadRow {
                        required property int index
                        width: content.width
                        compact: true
                        task: queue.tasks[index]
                        onCancelClicked: function (taskId) { queue.cancelTask(taskId) }
                        onRetryClicked: function (taskId) { queue.retryTask(taskId) }
                        onOpenClicked: function (taskId) { queue.openTask(taskId) }
                        onRemoveClicked: function (taskId) { queue.removeTask(taskId) }
                    }
                }
            }

            Item {
                Layout.fillWidth: true
                Layout.preferredHeight: root.compact ? 16 : Theme.pageGutter
            }

        }
    }
}
