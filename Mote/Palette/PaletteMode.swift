import AppKit

enum PaletteMode: String, CaseIterable, Identifiable {
    case launcher

    var id: String { rawValue }
    var systemImage: String { "magnifyingglass" }
    var placeholder: String { "Search for apps and commands…" }
}

/// The app a paste lands in, resolved once per show so nothing re-reads it per render.
struct PasteTarget: Equatable {
    let name: String
    /// Bundle path for `IconCache` — nil for a target with no on-disk bundle.
    let iconPath: String?

    init?(app: NSRunningApplication?) {
        guard let app, let name = app.localizedName else { return nil }
        self.name = name
        iconPath = app.bundleURL?.path
    }

    var pasteTitle: String { "Paste to \(name)" }
}
