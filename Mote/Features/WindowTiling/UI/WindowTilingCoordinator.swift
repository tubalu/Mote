import AppKit
import Carbon.HIToolbox

@MainActor
final class WindowTilingCoordinator {
    private static let defaultsInstalledKey = "windowTiling.defaultsInstalled"
    private static let moveShiftDefaultsInstalledKey = "windowTiling.moveShiftDefaultsInstalled"

    func tile(toward edge: WindowTileAlign) {
        apply { WindowTiling.tiled($0, toward: edge) }
    }

    func move(toward edge: WindowTileAlign) {
        apply { WindowTiling.moved($0, toward: edge) }
    }

    func installDefaultBindings(into hotKeys: HotKeyManager) {
        seedArrowPair(
            flag: Self.defaultsInstalledKey,
            left: .tileLeft, right: .tileRight,
            modifiers: [.control, .option], into: hotKeys)
        seedArrowPair(
            flag: Self.moveShiftDefaultsInstalledKey,
            left: .moveLeft, right: .moveRight,
            modifiers: [.control, .shift], into: hotKeys)
    }

    private func seedArrowPair(
        flag: String, left: HotKeyAction, right: HotKeyAction,
        modifiers: NSEvent.ModifierFlags, into hotKeys: HotKeyManager
    ) {
        guard !UserDefaults.standard.bool(forKey: flag) else { return }
        UserDefaults.standard.set(true, forKey: flag)
        seed(left, keyCode: Int(kVK_LeftArrow), modifiers: modifiers, into: hotKeys)
        seed(right, keyCode: Int(kVK_RightArrow), modifiers: modifiers, into: hotKeys)
    }

    private func seed(
        _ action: HotKeyAction, keyCode: Int, modifiers: NSEvent.ModifierFlags,
        into hotKeys: HotKeyManager
    ) {
        guard hotKeys.binding(for: action) == nil else { return }
        let shortcut = KeyShortcut(
            carbonKeyCode: keyCode,
            carbonModifiers: KeyShortcut.carbonModifiers(from: modifiers))
        let binding = HotKeyBinding.combo(shortcut)
        guard hotKeys.conflictOwner(of: binding, excluding: action) == nil else { return }
        hotKeys.setBinding(binding, for: action)
    }

    private func apply(_ transform: (WindowTileState) -> WindowTileState) {
        guard Permissions.ensureAccessibility() else {
            NSSound.beep()
            return
        }
        guard let snapshot = FrontmostWindowRunner.read() else {
            NSSound.beep()
            return
        }
        let current = WindowTiling.state(of: snapshot.frame, in: snapshot.screen)
        let target = WindowTiling.rect(for: transform(current), in: snapshot.screen)
        if !FrontmostWindowRunner.write(target, to: snapshot.element) {
            NSSound.beep()
        }
    }
}
