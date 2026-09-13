import AppKit
import Carbon.HIToolbox

@MainActor
final class WindowTilingCoordinator {
    private static let defaultsInstalledKey = "windowTiling.defaultsInstalled"

    func move() { perform(moving: true) }
    func resize() { perform(moving: false) }

    func installDefaultBindings(into hotKeys: HotKeyManager) {
        guard !UserDefaults.standard.bool(forKey: Self.defaultsInstalledKey) else { return }
        UserDefaults.standard.set(true, forKey: Self.defaultsInstalledKey)
        seed(.moveWindow, keyCode: Int(kVK_LeftArrow), into: hotKeys)
        seed(.resizeWindow, keyCode: Int(kVK_RightArrow), into: hotKeys)
    }

    private func seed(_ action: HotKeyAction, keyCode: Int, into hotKeys: HotKeyManager) {
        guard hotKeys.binding(for: action) == nil else { return }
        let shortcut = KeyShortcut(
            carbonKeyCode: keyCode,
            carbonModifiers: KeyShortcut.carbonModifiers(from: [.control, .option]))
        let binding = HotKeyBinding.combo(shortcut)
        guard hotKeys.conflictOwner(of: binding, excluding: action) == nil else { return }
        hotKeys.setBinding(binding, for: action)
    }

    private func perform(moving: Bool) {
        guard Permissions.ensureAccessibility() else {
            NSSound.beep()
            return
        }
        guard let snapshot = FrontmostWindowRunner.read() else {
            NSSound.beep()
            return
        }
        let current = WindowTiling.state(of: snapshot.frame, in: snapshot.screen)
        let next = moving
            ? WindowTiling.moved(current)
            : WindowTiling.resized(current, window: snapshot.frame, screen: snapshot.screen)
        let target = WindowTiling.rect(for: next, in: snapshot.screen)
        if !FrontmostWindowRunner.write(target, to: snapshot.element) {
            NSSound.beep()
        }
    }
}
