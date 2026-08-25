import Foundation

/// The UserDefaults keys `AppSettings` owns.
enum AppSettingsKey: String, CaseIterable {
    // Every raw value is spelled out so renaming a case can never rename a persisted key.
    case hyperKey = "hyperKeyPhysicalKey"
    case hyperKeyIncludesShift = "hyperKeyIncludesShift"
    case hyperKeyQuickPress = "hyperKeyQuickPress"
    case popToRootTimeout = "popToRootTimeout"
    case appearance = "appearance"
    case compactMode = "compactMode"
    case showFavoritesInCompactMode = "showFavoritesInCompactMode"
    case searchScopes = "launcherSearchScopes"
    case openOnCursorScreen = "openOnCursorScreen"
    case autoSwitchInputSource = "autoSwitchInputSource"
    case paletteDraggable = "paletteDraggable"
    case palettePosition = "palettePosition"
}
