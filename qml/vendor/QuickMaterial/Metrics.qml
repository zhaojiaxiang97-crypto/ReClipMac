pragma Singleton

import QtQuick

// Component sizes, spacing, and the density that scales them.
//
//     TextField { implicitHeight: Metrics.field }
//     Column { spacing: Metrics.space.medium }
//
// Density is the part worth understanding. Material's default sizes assume
// a finger: a text field is 56 tall because that is a comfortable target to
// hit without looking. On a desktop driven by a keyboard and a precise
// pointer, that is generous, and the specification says so — it defines a
// density scale from 0 down to -3, each step subtracting 4, for exactly
// this.
//
// So a compact desktop interface is not a departure from the specification.
// It is the specification at a lower density, and saying which one is the
// difference between a considered choice and numbers that drifted.
//
// Reduce density for dense, information-rich, expert interfaces. Leave it
// at 0 for anything glanced at, used rarely, or operated at arm's length —
// a login screen with one field is the opposite of dense, whatever else it
// is.
QtObject {
    id: root

    // 0 to -3. Each step removes 4 from every interactive height, and
    // nothing else: type, radii and padding are not density-scaled, because
    // shrinking text is a legibility decision rather than a density one.
    property int density: 0

    readonly property int _step: Math.max(-3, Math.min(0, density)) * 4

    // ────────────────────── interactive heights ──────────────────────

    readonly property int field: 56 + _step
    readonly property int button: 40 + _step
    readonly property int chip: 32 + _step
    readonly property int listItem: 56 + _step
    readonly property int listItemDense: 48 + _step
    readonly property int menuItem: 48 + _step

    // The minimum any pointer target may be, whatever it looks like. This
    // one does not scale with density: it is an accessibility floor, not a
    // style, and a control drawn smaller should grow its touch area rather
    // than shrink this.
    readonly property int minimumTarget: 48

    // A dialog is between 280 and 560 wide in the specification. Narrower
    // than 280 and its buttons stop fitting side by side; wider than 560
    // and the eye has to travel back too far between lines.
    readonly property int dialogWidthMin: 280
    readonly property int dialogWidthMax: 560
    readonly property int dialogWidth: 400

    // ─────────────────────────── fixed sizes ───────────────────────────

    readonly property QtObject icon: QtObject {
        readonly property int small: 18
        readonly property int medium: 24
        readonly property int large: 32
    }

    readonly property QtObject avatar: QtObject {
        readonly property int small: 32
        readonly property int medium: 40
        readonly property int large: 80
    }

    // ─────────────────────────── spacing ───────────────────────────
    //
    // A four-point grid. Everything that separates two things comes from
    // here, so the gaps in an interface are related to each other by
    // arithmetic rather than by eye.
    readonly property QtObject space: QtObject {
        readonly property int none: 0
        readonly property int extraSmall: 4
        readonly property int small: 8
        readonly property int medium: 16
        readonly property int large: 24
        readonly property int extraLarge: 32
        readonly property int huge: 48
    }

    // Inside a container, between its edge and its content.
    readonly property QtObject pad: QtObject {
        readonly property int card: 24
        readonly property int dialog: 24
        readonly property int field: 16
        readonly property int button: 24
        readonly property int chip: 16
        readonly property int listItem: 16
        readonly property int screen: 24
    }

    // Stroke widths.
    readonly property QtObject stroke: QtObject {
        readonly property real thin: 1
        readonly property real thick: 2
        // What an outlined text field grows to when focused. The change in
        // weight is what says "focused" at a glance; colour alone is not
        // enough for anyone who cannot distinguish it.
        readonly property real focus: 2
    }
}
