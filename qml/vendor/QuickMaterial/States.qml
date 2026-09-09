pragma Singleton

import QtQuick

// State layer opacities.
//
// Material expresses hover, focus, press and drag by laying a translucent
// film of the *content* colour over the component — not by changing the
// component's colour to a different one.
//
// The distinction matters more than it sounds. Swapping
// surfaceContainer for surfaceContainerHigh works only where a container
// role is already painted: on a transparent control the same swap jumps
// from nothing to a filled box, which is why bare icon buttons done that
// way flash a rectangle on hover. It also cannot express two states at
// once, and hovering a focused control is not rare — it is what happens
// every time someone reaches for the thing they just tabbed to.
//
// Only one layer is shown at a time, chosen by priority: pressed beats
// dragged, dragged beats focused, focused beats hovered. An earlier version
// here added them together and argued for it at length — that is wrong, and
// visibly so. Summed, a hovered and focused control reached 0.18 where
// Material renders 0.12, and with a press on top it hit the clamp at 0.24
// against Material's 0.12: twice the tint the specification asks for.
QtObject {
    readonly property real hover: 0.08
    readonly property real focus: 0.12
    readonly property real pressed: 0.12
    readonly property real dragged: 0.16

    // Not a state layer — a whole-component opacity for anything that
    // cannot be used. Applied to the component, so its text dims with it,
    // rather than laid over the top.
    readonly property real disabled: 0.38

    // What a disabled component's own container fades to.
    readonly property real disabledContainer: 0.12

    // The layer for a component in several states at once — the topmost of
    // them, not the sum. The old name for this was `combined`, which
    // described the arithmetic that was the bug.
    function topmost(hovered: bool, focused: bool, isPressed: bool): real {
        if (isPressed)
            return pressed;
        if (focused)
            return focus;
        if (hovered)
            return hover;
        return 0;
    }
}
