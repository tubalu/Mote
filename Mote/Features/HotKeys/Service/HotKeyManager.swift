import Foundation

/// Owns every binding: persistence, registration with both engines, conflicts and dispatch.
@MainActor
@Observable
final class HotKeyManager {
    var onTogglePalette: (() -> Void)?
    var onRunSystemAction: ((SystemAction.ID) -> Void)?
    /// Names what only the stores know; the fixed catalogs resolve here. Set in `AppCore.start()`.
    var displayName: ((HotKeyAction) -> String?)?

    /// The recorder currently capturing, which also pauses both engines.
    var recordingAction: HotKeyAction? {
        didSet {
            guard recordingAction != oldValue else { return }
            let recording = recordingAction != nil
            center.isPaused = recording
            doubleTapMonitor.isPaused = recording
            if let recordingAction {
                capture.start(action: recordingAction, hotKeys: self)
            } else {
                capture.stop()
            }
        }
    }

    let doubleTapMonitor = DoubleTapMonitor()
    /// Live state of the open recorder, read by its callout.
    let capture = ShortcutCaptureSession()

    private let center = HotKeyCenter()
    private var doubleTaps: [DoubleTapModifier: HotKeyAction] = [:]
    /// Every binding, loaded once in `start()` and written through on change.
    private var bindings: [HotKeyAction: HotKeyBinding] = [:]
    @ObservationIgnored private var candidateActionsCache: [HotKeyAction]?
    // Reused: the startup load decodes once per candidate action.
    private let decoder = JSONDecoder()
    private let encoder = JSONEncoder()
    private let boundKey = "boundAppBundleIDs"
    private let boundPaneKey = "boundPaneBundleIDs"

    func start() {
        for action in candidateActions { bindings[action] = storedBinding(for: action) }

        // `register` no-ops on an unbound item, so the fixed catalogs need no index of their own.
        for action in candidateActions { register(action) }

        doubleTapMonitor.onDoubleTap = { [weak self] modifier in
            guard let self, let action = doubleTaps[modifier] else { return }
            perform(action)
        }
        doubleTapMonitor.start()
        syncDoubleTaps()
    }

    /// Bundle IDs holding a per-app hotkey, so `start()` knows which records to load.
    var boundBundleIDs: [String] {
        UserDefaults.standard.stringArray(forKey: boundKey) ?? []
    }

    /// Settings-pane bundle IDs with a hotkey — same role as `boundBundleIDs`, own namespace.
    var boundPaneBundleIDs: [String] {
        UserDefaults.standard.stringArray(forKey: boundPaneKey) ?? []
    }

    func binding(for action: HotKeyAction) -> HotKeyBinding? { bindings[action] }

    private func storedBinding(for action: HotKeyAction) -> HotKeyBinding? {
        // The stored value is a JSON string; anything else reads as unbound.
        guard
            let json = UserDefaults.standard.string(forKey: action.defaultsKey),
            let data = json.data(using: .utf8)
        else { return nil }
        return try? decoder.decode(HotKeyBinding.self, from: data)
    }

    /// Persists or clears the binding and swaps live registration.
    func setBinding(_ binding: HotKeyBinding?, for action: HotKeyAction) {
        let previous = bindings[action]
        if let binding,
            let data = try? encoder.encode(binding),
            let json = String(data: data, encoding: .utf8)
        {
            bindings[action] = binding
            UserDefaults.standard.set(json, forKey: action.defaultsKey)
        } else {
            bindings[action] = nil
            UserDefaults.standard.removeObject(forKey: action.defaultsKey)
        }
        // Unregister unconditionally: the previous binding may have been a combo.
        center.unregister(id: action.defaultsKey)
        register(action)

        switch action {
        case .app(let bundleID):
            var set = Set(boundBundleIDs)
            if binding == nil { set.remove(bundleID) } else { set.insert(bundleID) }
            UserDefaults.standard.set(Array(set), forKey: boundKey)
        case .settingsPane(let bundleID):
            var set = Set(boundPaneBundleIDs)
            if binding == nil { set.remove(bundleID) } else { set.insert(bundleID) }
            UserDefaults.standard.set(Array(set), forKey: boundPaneKey)
        case .togglePalette, .systemAction:
            break
        }
        candidateActionsCache = nil
        // A rebuild walks every candidate; only a double-tap entering or leaving changes the map.
        if previous?.doubleTapModifier != nil || binding?.doubleTapModifier != nil {
            syncDoubleTaps()
        }
    }

    /// Include Shift redefines the chord, and a stored combo has the old one baked in.
    func retargetHyperBindings(includesShift: Bool) {
        for action in candidateActions {
            guard let shortcut = bindings[action]?.shortcut else { continue }
            let retargeted = shortcut.retargetingHyper(includesShift: includesShift)
            guard retargeted != shortcut else { continue }
            let binding = HotKeyBinding.combo(retargeted)
            // Skip a collision rather than clobber it: the second registration would fail silently.
            guard conflictOwner(of: binding, excluding: action) == nil else { continue }
            setBinding(binding, for: action)
        }
    }

    /// What else holds `binding`, or nil. Whole-binding comparison covers both kinds alike.
    func conflictOwner(of binding: HotKeyBinding, excluding action: HotKeyAction) -> String? {
        for candidate in candidateActions
        where candidate != action && self.binding(for: candidate) == binding {
            return displayName(of: candidate)
        }
        return nil
    }

    /// Every action that could hold a binding: the search space for conflicts and the map.
    private var candidateActions: [HotKeyAction] {
        if let candidateActionsCache { return candidateActionsCache }
        var actions = HotKeyAction.builtInActions
        actions += boundBundleIDs.map { .app(bundleID: $0) }
        actions += boundPaneBundleIDs.map { .settingsPane(bundleID: $0) }
        actions += SystemAction.ID.allCases.map { .systemAction(id: $0) }
        candidateActionsCache = actions
        return actions
    }

    private func displayName(of action: HotKeyAction) -> String {
        switch action {
        case .togglePalette:
            return "App Launcher"
        case .app(let bundleID), .settingsPane(let bundleID):
            return displayName?(action) ?? bundleID
        case .systemAction(let id):
            return SystemActionCatalog.action(id: id).name
        }
    }

    /// Hands a combo to Carbon; a double-tap has no per-action registration to make.
    private func register(_ action: HotKeyAction) {
        guard let shortcut = binding(for: action)?.shortcut else { return }
        center.register(id: action.defaultsKey, shortcut: shortcut) { [weak self] in
            self?.perform(action)
        }
    }

    /// Rebuilt wholesale, so the map can't drift from what is on disk.
    private func syncDoubleTaps() {
        doubleTaps = [:]
        for action in candidateActions {
            guard let modifier = binding(for: action)?.doubleTapModifier else { continue }
            doubleTaps[modifier] = action
        }
        doubleTapMonitor.update(bound: Set(doubleTaps.keys))
    }

    private func perform(_ action: HotKeyAction) {
        switch action {
        case .togglePalette: onTogglePalette?()
        case .app(let bundleID): AppLauncher.toggle(bundleID: bundleID)
        case .settingsPane(let bundleID): AppLauncher.openSettingsPane(bundleID: bundleID)
        case .systemAction(let id): onRunSystemAction?(id)
        }
    }
}
