import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import ReClip

Drawer {
    id: root

    property var settings: null
    property var controller: null
    property var platformStorage: null
    property bool toolsReady: false
    property string currentPage: "new"

    signal navigate(string page)

    edge: Qt.LeftEdge
    modal: true
    interactive: true
    width: parent ? Math.min(parent.width * 0.82, 380) : 360
    height: parent ? parent.height : 0
    closePolicy: Popup.CloseOnEscape | Popup.CloseOnPressOutside

    background: Rectangle {
        color: Theme.background
        border.width: 0
    }

    contentItem: Item {
        Loader {
            anchors.fill: parent
            sourceComponent: Qt.platform.os === "android" ? mobileNavigationPage
                             : (Qt.platform.os === "ios" ? iosSettingsPage : mobileSettingsPage)
        }

        Button {
            id: closeButton

            anchors.top: parent.top
            anchors.right: parent.right
            anchors.topMargin: 10
            anchors.rightMargin: 14
            width: 44
            height: 44
            padding: 0
            z: 1
            text: "关闭设置"
            onClicked: root.close()

            contentItem: IconGlyph {
                anchors.centerIn: parent
                name: "close"
                color: closeButton.down ? Theme.accent : Theme.muted
                size: 22
            }

            background: Rectangle {
                radius: width / 2
                color: closeButton.down ? Theme.violetSurface
                                         : (closeButton.hovered ? Theme.surfaceAlt : "transparent")
                border.width: 0
            }

            ToolTip.visible: hovered
            ToolTip.text: text
            ToolTip.delay: 600
        }
    }

    Component {
        id: mobileNavigationPage

        Item {
            ColumnLayout {
                anchors.fill: parent
                anchors.leftMargin: 20
                anchors.rightMargin: 20
                anchors.topMargin: 72
                anchors.bottomMargin: 20
                spacing: 16

                Label {
                    Layout.fillWidth: true
                    text: root.controller ? root.controller.productName : "Video Downloader"
                    color: Theme.text
                    font.family: Theme.fontFamily
                    font.pixelSize: 22
                    font.weight: Font.DemiBold
                    elide: Text.ElideRight
                }

                ColumnLayout {
                    Layout.fillWidth: true
                    spacing: 8

                    NavigationItem {
                        Layout.fillWidth: true
                        text: "下载工作台"
                        iconName: "download-add"
                        selected: root.currentPage !== "queue"
                        onClicked: {
                            root.navigate("new")
                            root.close()
                        }
                    }

                    NavigationItem {
                        Layout.fillWidth: true
                        text: "下载队列"
                        iconName: "queue"
                        selected: root.currentPage === "queue"
                        onClicked: {
                            root.navigate("queue")
                            root.close()
                        }
                    }
                }

                Rectangle {
                    Layout.fillWidth: true
                    Layout.preferredHeight: 1
                    color: Theme.border
                }

                RowLayout {
                    Layout.fillWidth: true
                    Layout.preferredHeight: 48
                    spacing: 12

                    IconGlyph {
                        name: "tools"
                        color: Theme.muted
                        size: 22
                    }

                    Label {
                        Layout.fillWidth: true
                        text: root.toolsReady ? "引擎状态：已就绪" : "引擎状态：未就绪"
                        color: root.toolsReady ? Theme.text : Theme.warningText
                        font.family: Theme.fontFamily
                        font.pixelSize: 14
                    }

                    Rectangle {
                        Layout.preferredWidth: 10
                        Layout.preferredHeight: 10
                        radius: 5
                        color: root.toolsReady ? Theme.signal : Theme.warning
                    }
                }

                Item { Layout.fillHeight: true }
            }
        }
    }

    Component {
        id: mobileSettingsPage

        SettingsPage {
            settings: root.settings
            controller: root.controller
            platformStorage: root.platformStorage
        }
    }

    Component {
        id: iosSettingsPage

        IosSettingsPage {
            settings: root.settings
            controller: root.controller
        }
    }
}
