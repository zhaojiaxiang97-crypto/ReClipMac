pragma Singleton

import QtQml
import QtQuick

QtObject {
    // Android keeps the dark Graphite Rose baseline from the phone references.
    // Desktop uses a light download workbench inspired by the attached Clash
    // layout: a quiet canvas, white cards and one clear blue action color.
    // The settings page still lets the user switch themes explicitly.
    property bool darkMode: Qt.platform.os === "android" || Qt.platform.os === "ios"

    // Keep Chinese UI text on a native system face. Qt will fall back to the
    // next suitable glyph source when a platform does not ship the preferred
    // family, which is more reliable than forcing a web-font-like stack.
    readonly property string fontFamily: Qt.platform.os === "windows" ? "Microsoft YaHei UI"
        : (Qt.platform.os === "osx" ? "PingFang SC"
        : (Qt.platform.os === "android" ? "Noto Sans CJK SC" : "Noto Sans"))
    readonly property string monoFamily: Qt.platform.os === "windows" ? "Cascadia Mono"
        : (Qt.platform.os === "android" ? "monospace" : "SF Mono")

    // Dark Graphite Rose palette for mobile and explicit dark mode.
    readonly property color graphite: "#151314"
    readonly property color surfaceDark: "#211D1E"
    readonly property color surfaceAltDark: "#2A2526"
    readonly property color surfaceRaisedDark: "#5B5354"
    readonly property color dividerDark: "#4B4546"
    readonly property color textDark: "#F1E8E9"
    readonly property color mutedDark: "#C1B4B6"
    readonly property color subtleDark: "#998D90"
    readonly property color rose: "#E3CDD1"
    readonly property color roseLight: "#C78996"
    readonly property color signalDark: "#80C43A"
    readonly property color amber: "#DDB767"
    readonly property color coral: "#D77979"

    // Desktop light palette. Blue is the primary interaction cue; green is
    // deliberately reserved for healthy tool and task states.
    readonly property color primaryBlue: "#1677FF"
    readonly property color primaryBlueHover: "#0958D9"
    readonly property color primaryBlueSoft: "#E7F1FF"
    readonly property color desktopCanvas: "#F3F4F6"
    readonly property color desktopSidebar: "#F0F2F5"
    readonly property color desktopSurfaceAlt: "#F8FAFC"
    readonly property color desktopSelection: "#DCEBFC"
    readonly property color desktopBorder: "#E6E8EB"
    readonly property color desktopText: "#182230"
    readonly property color desktopMuted: "#667085"
    readonly property color desktopSubtle: "#98A2B3"

    // Kept as named compatibility colors for components and documentation
    // that still use the earlier desktop palette names.
    readonly property color wechatGreen: "#07C160"
    readonly property color wechatGreenHover: "#06AD56"
    readonly property color wechatCanvas: desktopCanvas
    readonly property color wechatSidebar: desktopSidebar
    readonly property color wechatSurfaceAlt: desktopSurfaceAlt
    readonly property color wechatSelection: desktopSelection
    readonly property color wechatBorder: desktopBorder
    readonly property color wechatText: desktopText
    readonly property color wechatMuted: desktopMuted
    readonly property color wechatSubtle: desktopSubtle

    // Compatibility aliases keep existing QML components source-compatible
    // while the visual meaning of the former violet token moves to Rose.
    readonly property color ink: darkMode ? textDark : wechatText
    readonly property color canvasLight: wechatCanvas
    readonly property color violet: accent

    readonly property color background: darkMode ? graphite : desktopCanvas
    readonly property color surface: darkMode ? surfaceDark : "#FFFFFF"
    readonly property color surfaceAlt: darkMode ? surfaceAltDark : desktopSurfaceAlt
    readonly property color surfaceRaised: darkMode ? surfaceRaisedDark : primaryBlueSoft
    readonly property color selectionSurface: darkMode ? surfaceRaisedDark : desktopSelection
    readonly property color sidebarBackground: darkMode ? graphite : desktopSidebar
    readonly property color text: darkMode ? textDark : desktopText
    readonly property color muted: darkMode ? mutedDark : desktopMuted
    readonly property color subtle: darkMode ? subtleDark : desktopSubtle
    readonly property color border: darkMode ? dividerDark : desktopBorder
    readonly property color accent: darkMode ? rose : primaryBlue
    readonly property color accentHover: darkMode ? roseLight : primaryBlueHover
    readonly property color accentText: darkMode ? "#211D1E" : "#FFFFFF"
    readonly property color signal: darkMode ? signalDark : wechatGreen
    readonly property color success: signal
    readonly property color successBorder: darkMode ? "#5D8730" : "#B7E3C8"
    readonly property color warning: amber
    readonly property color danger: coral
    readonly property color warningSurface: darkMode ? "#332B21" : "#FFF7E8"
    readonly property color warningBorder: darkMode ? "#80652D" : "#F0D28F"
    readonly property color warningText: darkMode ? "#F0D993" : "#7A5A18"
    readonly property color dangerSurface: darkMode ? "#382426" : "#FFF0ED"
    readonly property color dangerBorder: darkMode ? "#844C50" : "#F2B1A6"
    readonly property color violetSurface: darkMode ? "#342D2F" : primaryBlueSoft
    readonly property color signalSurface: darkMode ? "#263522" : "#E9F7EF"

    readonly property int radiusAction: darkMode ? radiusPill : 6
    readonly property int radiusInput: darkMode ? 16 : 6
    readonly property int radiusControl: darkMode ? 12 : 6
    readonly property int radiusPanel: darkMode ? 20 : 9
    readonly property int radiusSmall: darkMode ? 8 : 5
    readonly property int radiusPill: 999
    readonly property int radiusSelection: darkMode ? radiusPill : 6
    readonly property int touchTarget: 44
    readonly property int sidebarWidth: darkMode ? 224 : 196
    readonly property int pageGutter: darkMode ? 16 : 24
    readonly property int pageTop: darkMode ? 16 : 20
    readonly property int pageSpacing: 16

    function stateColor(state) {
        if (state === "completed" || state === "ready") {
            return signal
        }
        if (state === "failed") {
            return danger
        }
        if (state === "queued" || state === "waiting" || state === "cancelled"
                || state === "interrupted") {
            return warning
        }
        return accent
    }

    function stateSurface(state) {
        if (state === "completed" || state === "ready") {
            return signalSurface
        }
        if (state === "failed") {
            return dangerSurface
        }
        if (state === "queued" || state === "waiting" || state === "cancelled"
                || state === "interrupted") {
            return warningSurface
        }
        return violetSurface
    }
}
