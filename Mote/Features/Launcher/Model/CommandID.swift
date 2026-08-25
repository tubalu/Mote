import Foundation

/// Built-in launcher actions, surfaced alongside apps and system actions.
enum CommandID: String, CaseIterable, Sendable {
    case settings = "command:settings"
    case about = "command:about"
    case quit = "command:quit"

    var name: String {
        switch self {
        case .settings: return "Settings"
        case .about: return "About Mote"
        case .quit: return "Quit Mote"
        }
    }

    var sfSymbol: String {
        switch self {
        case .settings: return "gearshape"
        case .about: return "info.circle"
        case .quit: return "power"
        }
    }

    /// The built-ins with a global shortcut of their own; the rest open from the launcher.
    var hotKeyAction: HotKeyAction? { nil }
}
