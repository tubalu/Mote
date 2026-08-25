import Foundation

/// Ordered like a bare backspace: a screen is only left once the search field is empty.
enum PaletteEscapeAction: Equatable {
    case closeMenu
    case clearQuery
    case hidePalette

    static func resolve(menuOpen: Bool, query: String, mode: PaletteMode) -> Self {
        if menuOpen { return .closeMenu }
        if !query.isEmpty { return .clearQuery }
        return .hidePalette
    }
}
