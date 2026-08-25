import Foundation

/// Everything in Mote a global shortcut can be bound to.
enum HotKeyAction: Hashable, Sendable {
    case togglePalette
    case app(bundleID: String)
    case settingsPane(bundleID: String)
    case systemAction(id: SystemAction.ID)

    /// The UserDefaults key, and the `HotKeyCenter` registration id: one per action.
    var defaultsKey: String {
        switch self {
        case .togglePalette: "hotkey.togglePalette"
        case .app(let bundleID): "hotkey.app." + bundleID
        case .settingsPane(let bundleID): "hotkey.pane." + bundleID
        case .systemAction(let id): "hotkey.systemAction." + id.rawValue
        }
    }

    /// The fixed actions every install can bind; the per-item catalogs extend them at launch.
    static let builtInActions: [HotKeyAction] = [
        .togglePalette
    ]
}
