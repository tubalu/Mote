import Foundation

/// Drives the real Escape precedence, so one press can never skip a step the user can still see —
/// an open menu, typed text — and land on the one that throws work away.
@main
@MainActor
struct PaletteEscapeTests {
    static var failures = 0
    static var passes = 0

    static func expect(_ actual: PaletteEscapeAction, _ expected: PaletteEscapeAction, _ message: String) {
        if actual == expected {
            passes += 1
        } else {
            failures += 1
            print("FAIL: \(message) — got \(actual), want \(expected)")
        }
    }

    static func main() {
        expect(
            PaletteEscapeAction.resolve(menuOpen: true, query: "notes", mode: .launcher),
            .closeMenu,
            "an open menu closes before anything else")
        expect(
            PaletteEscapeAction.resolve(menuOpen: false, query: "notes", mode: .launcher),
            .clearQuery,
            "a typed launcher query clears before the palette hides")
        expect(
            PaletteEscapeAction.resolve(menuOpen: false, query: "", mode: .launcher),
            .hidePalette,
            "an empty launcher query hides the palette")
        expect(
            PaletteEscapeAction.resolve(menuOpen: true, query: "", mode: .launcher),
            .closeMenu,
            "a menu outranks an empty launcher query")

        print("\(passes) passed, \(failures) failed")
        if failures > 0 { exit(1) }
    }
}
