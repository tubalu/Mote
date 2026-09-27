import AppKit
import Carbon.HIToolbox

@MainActor
final class WindowTilingCoordinator {
    private static let defaultsInstalledKey = "windowTiling.defaultsInstalled"
    private static let moveShiftDefaultsInstalledKey = "windowTiling.moveShiftDefaultsInstalled"
    private static let maximizeDefaultsInstalledKey = "windowTiling.maximizeDefaultsInstalled"

    func maximize() {
        apply { _ in .full }
    }

    func tile(toward edge: WindowTileAlign) {
        apply { WindowTiling.tiled($0, toward: edge) }
    }

    func move(toward edge: WindowTileAlign) {
        apply { WindowTiling.moved($0, toward: edge) }
    }

    func installDefaultBindings(into hotKeys: HotKeyManager) {
        let tile: NSEvent.ModifierFlags = [.control, .option]
        seedOnce(flag: Self.defaultsInstalledKey) {
            seed(.tileLeft, keyCode: Int(kVK_LeftArrow), modifiers: tile, into: hotKeys)
            seed(.tileRight, keyCode: Int(kVK_RightArrow), modifiers: tile, into: hotKeys)
        }
        seedOnce(flag: Self.moveShiftDefaultsInstalledKey) {
            let move: NSEvent.ModifierFlags = [.control, .shift]
            seed(.moveLeft, keyCode: Int(kVK_LeftArrow), modifiers: move, into: hotKeys)
            seed(.moveRight, keyCode: Int(kVK_RightArrow), modifiers: move, into: hotKeys)
        }
        seedOnce(flag: Self.maximizeDefaultsInstalledKey) {
            seed(.maximize, keyCode: Int(kVK_UpArrow), modifiers: tile, into: hotKeys)
        }
    }

    private func seedOnce(flag: String, _ install: () -> Void) {
        guard !UserDefaults.standard.bool(forKey: flag) else { return }
        UserDefaults.standard.set(true, forKey: flag)
        install()
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
