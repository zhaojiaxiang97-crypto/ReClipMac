pragma Singleton

import QtQml
import QtQuick

QtObject {
    property bool darkMode: false

    readonly property string fontFamily: "Noto Sans"
    readonly property string monoFamily: "IBM Plex Mono"

    readonly property color ink: "#101726"
    readonly property color canvasLight: "#F4F6FA"
    readonly property color violet: "#6C5CE7"
    readonly property color signal: "#16B8A6"
    readonly property color coral: "#E67863"
    readonly property color amber: "#E9B95A"

    readonly property color background: darkMode ? "#0B111D" : canvasLight
    readonly property color surface: darkMode ? "#151D2C" : "#FFFFFF"
    readonly property color surfaceAlt: darkMode ? "#202B3D" : "#E9EDF4"
    readonly property color text: darkMode ? "#F6F8FC" : ink
    readonly property color muted: darkMode ? "#A9B4C7" : "#596579"
    readonly property color subtle: darkMode ? "#77869D" : "#8390A4"
    readonly property color border: darkMode ? "#2D3A4F" : "#D8DEE8"
    readonly property color accent: violet
    readonly property color success: signal
    readonly property color successBorder: darkMode ? "#1F746B" : "#A8E1D8"
    readonly property color warning: amber
    readonly property color danger: coral
    readonly property color warningSurface: darkMode ? "#332C1F" : "#FFF7E8"
    readonly property color warningBorder: darkMode ? "#80652D" : "#F0D28F"
    readonly property color warningText: darkMode ? "#F6D993" : "#7A5A18"
    readonly property color dangerSurface: darkMode ? "#3A2426" : "#FFF0ED"
    readonly property color dangerBorder: darkMode ? "#8B4D4B" : "#F2B1A6"
    readonly property color violetSurface: darkMode ? "#2B2751" : "#F0EEFF"
    readonly property color signalSurface: darkMode ? "#173936" : "#E8FAF6"

    readonly property int radiusInput: 12
    readonly property int radiusControl: 8
    readonly property int radiusSmall: 6
    readonly property int touchTarget: 44

    function stateColor(state) {
        if (state === "completed" || state === "ready") {
            return signal
        }
        if (state === "failed") {
            return coral
        }
        if (state === "queued" || state === "waiting" || state === "cancelled") {
            return amber
        }
        return violet
    }

    function stateSurface(state) {
        if (state === "completed" || state === "ready") {
            return signalSurface
        }
        if (state === "failed") {
            return dangerSurface
        }
        if (state === "queued" || state === "waiting" || state === "cancelled") {
            return warningSurface
        }
        return violetSurface
    }
}
