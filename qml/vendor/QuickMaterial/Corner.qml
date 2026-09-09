pragma Singleton

import QtQuick

// The Material 3 shape scale.
//
//     Rectangle { radius: Corner.large }
//
// Named Corner rather than Shape, which is what the specification calls
// this scale. `Shape` is the type QtQuick.Shapes exports, and a singleton
// of that name collides with it in *both* import orders — one of which
// fails silently, leaving `radius: Corner.large` undefined and the corners
// square. A token scale and a vector-drawing module are exactly the two
// things anyone would import together.
//
// Seven steps and nothing in between. The value of a scale is that it is
// short: radii picked individually drift into 9, 10, 11, 13, 14 — numbers
// nobody chose, that no two components share, and that read as noise rather
// than as a family.
//
// `full` is not a number here. A pill has to be half the height of whatever
// it is on, and a constant stops being that the moment a size changes, so
// it is written `radius: height / 2` at the point of use. `Corner.full()`
// exists for cases where that is awkward to write inline.
QtObject {
    id: root

    readonly property int none: 0
    readonly property int extraSmall: 4
    readonly property int small: 8
    readonly property int medium: 12
    readonly property int large: 16
    readonly property int extraLarge: 28

    // The steps in order, for anything that needs to walk them — snapping a
    // legacy value, or animating between two.
    readonly property var steps: [none, extraSmall, small, medium, large, extraLarge]

    function full(height: real): real {
        return height / 2;
    }

    // The nearest step to an arbitrary radius. For migrating a codebase
    // that grew its own numbers: run it once, take the answers, write them
    // down as names.
    function snap(value: real): int {
        let best = root.none;
        let bestDelta = Infinity;
        for (const step of root.steps) {
            const delta = Math.abs(step - value);
            if (delta < bestDelta) {
                bestDelta = delta;
                best = step;
            }
        }
        return best;
    }
}
