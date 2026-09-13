# Window Tiling Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Ship TinyWin’s two-shortcut window cycle inside Mote (⌃⌥← move, ⌃⌥→ resize) without merging the TinyWin git repo or Rectangle’s app shell.

**Architecture:** Pure geometry lives in `Mote/Features/WindowTiling/Model/WindowTiling.swift`. `FrontmostWindowRunner` is the only AX/NSScreen I/O. `WindowTilingCoordinator` owns Accessibility, beeps, and the cycle. `AppCore.start()` wires two new `HotKeyAction`s after `hotKeys.start()`.

**Tech Stack:** Swift 6, AppKit, ApplicationServices (AX), Carbon `RegisterEventHotKey` via existing `HotKeyManager`, Mote standalone test harnesses (`./Scripts/run-tests.sh`). Zero new packages.

## Global Constraints

- Work only in `/Users/yong/code/tinycast`. No commits, copies of Sparkle/MASShortcut, or edits in `/Users/yong/code/tinyWindow`.
- Mote stays AGPL-3.0. Copied geometry is MIT (Rectangle / TinyWin / Spectacle) — attribute in `NOTICE.md`.
- `Mote/Features/*/Model/` may not `import AppKit`, `SwiftUI`, or `Cocoa`.
- macOS 26+, Swift 6, no third-party dependencies, no `NSAlert`.
- Default chords: ⌃⌥← Move Window, ⌃⌥→ Resize Window. Do not steal a chord another Mote action already owns. Seed once via `windowTiling.defaultsInstalled`.
- No palette `CommandID`s, no new Settings tab, no WindowMover chain, no size-limit HUD.

## File map

| File | Role |
| --- | --- |
| Create `Mote/Features/WindowTiling/Model/WindowTiling.swift` | Size/align/state + cycle math + screen pick |
| Create `Tests/window-tiling-test.swift` | Harness compiling that Model file |
| Create `Mote/Features/WindowTiling/Service/FrontmostWindowRunner.swift` | AX front window, Cocoa↔AX coords, set frame |
| Create `Mote/Features/WindowTiling/UI/WindowTilingCoordinator.swift` | Gate, beep, cycle, default bindings |
| Create `docs/features/window-tiling.md` | Invariants |
| Modify `Mote/Features/HotKeys/Model/HotKeyAction.swift` | `.moveWindow`, `.resizeWindow` |
| Modify `Mote/Features/HotKeys/Service/HotKeyManager.swift` | Closures, display names, `setBinding` switch |
| Modify `Tests/hotkey-test.swift` | Built-in actions + defaultsKey |
| Modify `Mote/App/AppCore.swift` | Own coordinator, wire after `hotKeys.start()` |
| Modify `Mote/Features/Settings/Panes/GeneralSettingsView.swift` | Two `ShortcutRecorder`s |
| Modify `Scripts/run-tests.sh`, `docs/testing.md`, `docs/architecture.md`, `docs/features/hotkeys.md`, `docs/README.md`, `AGENTS.md`, `README.md`, `NOTICE.md`, `website/content/docs/reference/shortcuts.md`, `website/content/docs/reference/hotkeys.md` | Docs stay true |

`project.yml` already compiles everything under `Mote/`; no XcodeGen source-list change.

---

### Task 1: Geometry model + harness

**Files:**
- Create: `Mote/Features/WindowTiling/Model/WindowTiling.swift`
- Create: `Tests/window-tiling-test.swift`
- Modify: `Scripts/run-tests.sh` (add one `run` line after `volume-test`)
- Modify: `docs/testing.md` harness table

**Interfaces:**
- Consumes: nothing
- Produces:
  - `enum WindowTileSize: Int, CaseIterable, Equatable` with `third`, `half`, `twoThirds`, `full`; `nextLarger` / `nextSmaller` as `WindowTileSize?`
  - `enum WindowTileAlign: Int, CaseIterable, Equatable` with `left`, `center`, `right`
  - `struct WindowTileState: Equatable` with `size`, `align`, `static let full`, `var isFull: Bool`
  - `enum WindowTiling` with:
    - `static func state(of window: CGRect, in screen: CGRect) -> WindowTileState`
    - `static func resized(_ state: WindowTileState, window: CGRect, screen: CGRect) -> WindowTileState`
    - `static func moved(_ state: WindowTileState) -> WindowTileState`
    - `static func rect(for state: WindowTileState, in screen: CGRect) -> CGRect`
    - `static func preferredScreen(for window: CGRect, among screens: [CGRect], fallback: CGRect) -> CGRect`
  - Tolerance `0.08`; space threshold `max(40, screen.width * 0.08)` (same as TinyWin)

- [ ] **Step 1: Write the failing harness**

Create `Tests/window-tiling-test.swift`:

```swift
import CoreGraphics
import Foundation

@main
enum WindowTilingTests {
    static var failures = 0
    static var passes = 0
    static let screen = CGRect(x: 0, y: 0, width: 1200, height: 800)

    static func expect(_ condition: @autoclosure () -> Bool, _ message: String) {
        if condition() {
            passes += 1
        } else {
            failures += 1
            print("FAIL: \(message)")
        }
    }

    static func main() {
        resizeShrinksFromFullAlongTheRightEdge()
        resizeExpandsFromLeftThirdTowardFull()
        moveCyclesRightCenterLeftAtTheSameSize()
        moveLeavesFullScreenUnchanged()
        centerThirdExpandsRightIntoRightTwoThirds()
        detectsRightHalfFromGeometry()
        preferredScreenPicksLargestIntersection()
        print("\(passes) passed, \(failures) failed")
        if failures > 0 { exit(1) }
    }

    static func resizeShrinksFromFullAlongTheRightEdge() {
        var state = WindowTileState.full
        var window = WindowTiling.rect(for: state, in: screen)
        state = WindowTiling.resized(state, window: window, screen: screen)
        expect(state == WindowTileState(size: .twoThirds, align: .right), "full → 2/3 right")
        window = WindowTiling.rect(for: state, in: screen)
        state = WindowTiling.resized(state, window: window, screen: screen)
        expect(state == WindowTileState(size: .half, align: .right), "2/3 right → 1/2 right")
        window = WindowTiling.rect(for: state, in: screen)
        state = WindowTiling.resized(state, window: window, screen: screen)
        expect(state == WindowTileState(size: .third, align: .right), "1/2 right → 1/3 right")
        window = WindowTiling.rect(for: state, in: screen)
        state = WindowTiling.resized(state, window: window, screen: screen)
        expect(state == .full, "1/3 right → full")
    }

    static func resizeExpandsFromLeftThirdTowardFull() {
        var state = WindowTileState(size: .third, align: .left)
        var window = WindowTiling.rect(for: state, in: screen)
        state = WindowTiling.resized(state, window: window, screen: screen)
        expect(state == WindowTileState(size: .half, align: .left), "left 1/3 → left 1/2")
        window = WindowTiling.rect(for: state, in: screen)
        state = WindowTiling.resized(state, window: window, screen: screen)
        expect(state == WindowTileState(size: .twoThirds, align: .left), "left 1/2 → left 2/3")
        window = WindowTiling.rect(for: state, in: screen)
        state = WindowTiling.resized(state, window: window, screen: screen)
        expect(state == .full, "left 2/3 → full")
    }

    static func moveCyclesRightCenterLeftAtTheSameSize() {
        var state = WindowTileState(size: .half, align: .right)
        state = WindowTiling.moved(state)
        expect(state == WindowTileState(size: .half, align: .center), "right → center")
        state = WindowTiling.moved(state)
        expect(state == WindowTileState(size: .half, align: .left), "center → left")
        state = WindowTiling.moved(state)
        expect(state == WindowTileState(size: .half, align: .right), "left → right")
    }

    static func moveLeavesFullScreenUnchanged() {
        expect(WindowTiling.moved(.full) == .full, "move leaves full unchanged")
    }

    static func centerThirdExpandsRightIntoRightTwoThirds() {
        let state = WindowTileState(size: .third, align: .center)
        let window = WindowTiling.rect(for: state, in: screen)
        let next = WindowTiling.resized(state, window: window, screen: screen)
        expect(next == WindowTileState(size: .twoThirds, align: .right), "center 1/3 → right 2/3")
    }

    static func detectsRightHalfFromGeometry() {
        let window = WindowTiling.rect(
            for: WindowTileState(size: .half, align: .right), in: screen)
        expect(
            WindowTiling.state(of: window, in: screen)
                == WindowTileState(size: .half, align: .right),
            "right half round-trips")
    }

    static func preferredScreenPicksLargestIntersection() {
        let left = CGRect(x: 0, y: 0, width: 1000, height: 800)
        let right = CGRect(x: 1000, y: 0, width: 1000, height: 800)
        let window = CGRect(x: 900, y: 0, width: 400, height: 800)
        let picked = WindowTiling.preferredScreen(
            for: window, among: [left, right], fallback: left)
        expect(picked == right, "largest intersection wins")
        let miss = CGRect(x: 3000, y: 0, width: 100, height: 100)
        expect(
            WindowTiling.preferredScreen(for: miss, among: [left, right], fallback: left) == left,
            "no intersection → fallback")
    }
}
```

Add to `Scripts/run-tests.sh` after the `volume-test` line:

```sh
run window-tiling-test     Mote/Features/WindowTiling/Model/WindowTiling.swift
```

- [ ] **Step 2: Run the harness and confirm it fails to compile**

Run: `./Scripts/run-tests.sh window-tiling-test`

Expected: compile error, `WindowTiling` / `WindowTileState` not found (or the `run` helper cannot find the source yet). Do not add a stub that makes tests pass.

- [ ] **Step 3: Implement the model**

Create `Mote/Features/WindowTiling/Model/WindowTiling.swift`. `import CoreGraphics` and `import Foundation` only. Port TinyWin’s `TinyWinLayout` math (not `subAction` / `resultingAction`):

```swift
import CoreGraphics
import Foundation

enum WindowTileSize: Int, CaseIterable, Equatable {
    case third, half, twoThirds, full

    var nextLarger: WindowTileSize? {
        switch self {
        case .third: return .half
        case .half: return .twoThirds
        case .twoThirds: return .full
        case .full: return nil
        }
    }

    var nextSmaller: WindowTileSize? {
        switch self {
        case .full: return .twoThirds
        case .twoThirds: return .half
        case .half: return .third
        case .third: return nil
        }
    }
}

enum WindowTileAlign: Int, CaseIterable, Equatable {
    case left, center, right
}

struct WindowTileState: Equatable {
    var size: WindowTileSize
    var align: WindowTileAlign
    static let full = WindowTileState(size: .full, align: .left)
    var isFull: Bool { size == .full }
}

enum WindowTiling {
    private static let sizeRatioTolerance: CGFloat = 0.08

    static func state(of window: CGRect, in screen: CGRect) -> WindowTileState {
        guard screen.width > 1 else { return .full }
        let inset = spaceThreshold(in: screen)
        let leftGap = window.minX - screen.minX
        let rightGap = screen.maxX - window.maxX
        let widthRatio = window.width / screen.width
        if leftGap <= inset && rightGap <= inset { return .full }
        if widthRatio >= 0.88 { return .full }
        let size: WindowTileSize
        if widthRatio >= 0.58 { size = .twoThirds }
        else if widthRatio >= 0.42 { size = .half }
        else { size = .third }
        let align: WindowTileAlign
        if leftGap <= inset { align = .left }
        else if rightGap <= inset { align = .right }
        else { align = .center }
        return WindowTileState(size: size, align: align)
    }

    static func resized(
        _ state: WindowTileState, window: CGRect, screen: CGRect
    ) -> WindowTileState {
        if state.size == .third && state.align == .right { return .full }
        let inset = spaceThreshold(in: screen)
        let spaceOnRight = screen.maxX - window.maxX > inset
        let spaceOnLeft = window.minX - screen.minX > inset
        if state.isFull || (!spaceOnRight && !spaceOnLeft) {
            return WindowTileState(size: .twoThirds, align: .right)
        }
        if spaceOnRight { return expandRight(state) }
        return shrinkKeepingRight(state)
    }

    static func moved(_ state: WindowTileState) -> WindowTileState {
        guard !state.isFull else { return state }
        switch state.align {
        case .right: return WindowTileState(size: state.size, align: .center)
        case .center: return WindowTileState(size: state.size, align: .left)
        case .left: return WindowTileState(size: state.size, align: .right)
        }
    }

    static func rect(for state: WindowTileState, in screen: CGRect) -> CGRect {
        if state.isFull { return screen }
        let third = floor(screen.width / 3.0)
        let half = floor(screen.width / 2.0)
        let twoThirds = screen.width - third
        let width: CGFloat
        switch state.size {
        case .third: width = third
        case .half: width = half
        case .twoThirds: width = twoThirds
        case .full: return screen
        }
        let x: CGFloat
        switch state.align {
        case .left: x = screen.minX
        case .right: x = screen.maxX - width
        case .center:
            switch state.size {
            case .third: x = screen.minX + third
            case .half: x = screen.minX + floor((screen.width - half) / 2.0)
            case .twoThirds: x = screen.minX + floor((screen.width - twoThirds) / 2.0)
            case .full: x = screen.minX
            }
        }
        return CGRect(x: x, y: screen.minY, width: width, height: screen.height)
    }

    static func preferredScreen(
        for window: CGRect, among screens: [CGRect], fallback: CGRect
    ) -> CGRect {
        let best = screens.max { a, b in
            area(a.intersection(window)) < area(b.intersection(window))
        }
        guard let best, best.intersects(window) else { return fallback }
        return best
    }

    private static func area(_ rect: CGRect) -> CGFloat {
        max(0, rect.width) * max(0, rect.height)
    }

    private static func expandRight(_ state: WindowTileState) -> WindowTileState {
        let left = leftFraction(state)
        var size = state.size
        while let next = size.nextLarger {
            size = next
            if size == .full { return .full }
            if let align = exactAlign(left: left, size: size) {
                return WindowTileState(size: size, align: align)
            }
        }
        return .full
    }

    private static func shrinkKeepingRight(_ state: WindowTileState) -> WindowTileState {
        guard let smaller = state.size.nextSmaller else { return .full }
        return WindowTileState(size: smaller, align: .right)
    }

    private static func leftFraction(_ state: WindowTileState) -> CGFloat {
        if state.isFull { return 0 }
        switch (state.size, state.align) {
        case (_, .left): return 0
        case (.third, .center): return 1.0 / 3.0
        case (.third, .right): return 2.0 / 3.0
        case (.half, .center): return 0.25
        case (.half, .right): return 0.5
        case (.twoThirds, .center): return 1.0 / 6.0
        case (.twoThirds, .right): return 1.0 / 3.0
        default: return 0
        }
    }

    private static func exactAlign(left: CGFloat, size: WindowTileSize) -> WindowTileAlign? {
        for align in WindowTileAlign.allCases {
            let candidate = WindowTileState(size: size, align: align)
            if abs(leftFraction(candidate) - left) <= sizeRatioTolerance { return align }
        }
        return nil
    }

    private static func spaceThreshold(in screen: CGRect) -> CGFloat {
        max(40, screen.width * 0.08)
    }
}
```

Add this row to the harness table in `docs/testing.md`:

`| `window-tiling-test` | `WindowTiling/Model/WindowTiling.swift` |`

- [ ] **Step 4: Run the harness**

Run: `./Scripts/run-tests.sh window-tiling-test`

Expected: all expects pass, `0 failed`.

Also: `grep -rln 'import AppKit\|import SwiftUI\|import Cocoa' Mote/Features/*/Model/` must print nothing.

- [ ] **Step 5: Commit**

```bash
git add Mote/Features/WindowTiling/Model/WindowTiling.swift Tests/window-tiling-test.swift Scripts/run-tests.sh docs/testing.md
git commit -m "$(cat <<'EOF'
feat: add WindowTiling geometry and harness

Port TinyWin's 1/3–1/2–2/3–full cycle as a Foundation-only model Mote can test without AppKit.
EOF
)"
```

---

### Task 2: HotKeyAction + dispatch

**Files:**
- Modify: `Mote/Features/HotKeys/Model/HotKeyAction.swift`
- Modify: `Mote/Features/HotKeys/Service/HotKeyManager.swift`
- Modify: `Tests/hotkey-test.swift` (`commandActions()`)
- Modify: `Mote/App/AppCore.swift` (`hotKeyDisplayName` exhaustive switch only)

**Interfaces:**
- Consumes: `HotKeyAction` as it exists today (`togglePalette`, `app`, `settingsPane`, `systemAction`)
- Produces:
  - `HotKeyAction.moveWindow` with `defaultsKey == "hotkey.window.move"`
  - `HotKeyAction.resizeWindow` with `defaultsKey == "hotkey.window.resize"`
  - `HotKeyAction.builtInActions == [.togglePalette, .moveWindow, .resizeWindow]`
  - `HotKeyManager.onMoveWindow: (() -> Void)?`
  - `HotKeyManager.onResizeWindow: (() -> Void)?`
  - `displayName(of: .moveWindow) == "Move Window"`
  - `displayName(of: .resizeWindow) == "Resize Window"`
  - `perform(.moveWindow)` calls `onMoveWindow?()`; `perform(.resizeWindow)` calls `onResizeWindow?()`

- [ ] **Step 1: Extend `commandActions()` so the harness fails**

In `Tests/hotkey-test.swift`, after the existing `commandActions()` expects, add:

```swift
        expect(
            HotKeyAction.builtInActions == [.togglePalette, .moveWindow, .resizeWindow],
            "built-ins are palette, move window, resize window")
        expect(
            HotKeyAction.moveWindow.defaultsKey == "hotkey.window.move",
            "move window persists under hotkey.window.move")
        expect(
            HotKeyAction.resizeWindow.defaultsKey == "hotkey.window.resize",
            "resize window persists under hotkey.window.resize")
```

- [ ] **Step 2: Run hotkey-test and confirm failure**

Run: `./Scripts/run-tests.sh hotkey-test`

Expected: compile error, `moveWindow` / `resizeWindow` not members of `HotKeyAction`.

- [ ] **Step 3: Add the cases and exhaustive switches**

`HotKeyAction.swift` — add cases and keys; put the new actions in `builtInActions`:

```swift
enum HotKeyAction: Hashable, Sendable {
    case togglePalette
    case moveWindow
    case resizeWindow
    case app(bundleID: String)
    case settingsPane(bundleID: String)
    case systemAction(id: SystemAction.ID)

    var defaultsKey: String {
        switch self {
        case .togglePalette: "hotkey.togglePalette"
        case .moveWindow: "hotkey.window.move"
        case .resizeWindow: "hotkey.window.resize"
        case .app(let bundleID): "hotkey.app." + bundleID
        case .settingsPane(let bundleID): "hotkey.pane." + bundleID
        case .systemAction(let id): "hotkey.systemAction." + id.rawValue
        }
    }

    static let builtInActions: [HotKeyAction] = [
        .togglePalette, .moveWindow, .resizeWindow
    ]
}
```

`HotKeyManager.swift`:

- Add `var onMoveWindow: (() -> Void)?` and `var onResizeWindow: (() -> Void)?` next to `onTogglePalette`.
- In `setBinding`, change `case .togglePalette, .systemAction:` to `case .togglePalette, .moveWindow, .resizeWindow, .systemAction:`.
- In `displayName(of:)`:

```swift
        case .togglePalette:
            return "App Launcher"
        case .moveWindow:
            return "Move Window"
        case .resizeWindow:
            return "Resize Window"
```

- In `perform`:

```swift
        case .togglePalette: onTogglePalette?()
        case .moveWindow: onMoveWindow?()
        case .resizeWindow: onResizeWindow?()
        case .app(let bundleID): AppLauncher.toggle(bundleID: bundleID)
        case .settingsPane(let bundleID): AppLauncher.openSettingsPane(bundleID: bundleID)
        case .systemAction(let id): onRunSystemAction?(id)
```

`AppCore.hotKeyDisplayName(for:)` currently `case .togglePalette, .systemAction: return nil`. Extend to `case .togglePalette, .moveWindow, .resizeWindow, .systemAction:` so Swift 6 exhaustive-switch still compiles. Wiring the closures is Task 4.

- [ ] **Step 4: Run hotkey-test and a Debug compile**

Run: `./Scripts/run-tests.sh hotkey-test`

Expected: existing counts still pass plus the three new expects.

Run: `make`

Expected: BUILD SUCCEEDED.

- [ ] **Step 5: Commit**

```bash
git add Mote/Features/HotKeys/Model/HotKeyAction.swift Mote/Features/HotKeys/Service/HotKeyManager.swift Mote/App/AppCore.swift Tests/hotkey-test.swift
git commit -m "$(cat <<'EOF'
feat: register Move Window and Resize Window hotkey actions

Give tiling its own HotKeyAction cases and dispatch closures so chords persist like the palette shortcut.
EOF
)"
```

---

### Task 3: Frontmost window runner

**Files:**
- Create: `Mote/Features/WindowTiling/Service/FrontmostWindowRunner.swift`

**Interfaces:**
- Consumes: `WindowTiling.preferredScreen(for:among:fallback:)`
- Produces:
  - `enum FrontmostWindowRunner`
  - `struct FrontmostWindowRunner.Snapshot` with `element: AXUIElement`, `frame: CGRect` (Cocoa), `screen: CGRect` (that display’s `visibleFrame`, Cocoa)
  - `static func read() -> Snapshot?`
  - `static func write(_ frame: CGRect, to element: AXUIElement) -> Bool`
  - AX uses top-left global coords; `frame` / `screen` / `write` use Cocoa bottom-left like `NSScreen.visibleFrame`

- [ ] **Step 1: There is no AX harness** — mutating the user’s windows is forbidden. Implement the runner; verify with `make`. This file is `Service/`, so AppKit is allowed. Purity grep must still ignore it.

- [ ] **Step 2: Implement `FrontmostWindowRunner`**

Create `Mote/Features/WindowTiling/Service/FrontmostWindowRunner.swift` with: `read()` (frontmost app → focused window else first window → AX frame → Cocoa → `preferredScreen`); `write` (Cocoa → AX, set size then origin then size). Convert Y using the height of the display whose frame origin is `(0,0)`. Bridge AX values the same way `SystemActionRunner` already does. If Swift 6 rejects `as! AXUIElement`, use optional `as?` after the CF type check.

Write size, then origin, then size again — AX applies each attribute separately and a display’s max size can clip the first size.

Full source for the engineer:

```swift
import AppKit
@preconcurrency import ApplicationServices

enum FrontmostWindowRunner {
    struct Snapshot {
        let element: AXUIElement
        let frame: CGRect
        let screen: CGRect
    }

    static func read() -> Snapshot? {
        guard let app = NSWorkspace.shared.frontmostApplication else { return nil }
        let appElement = AXUIElementCreateApplication(app.processIdentifier)
        guard let element = focusedWindow(in: appElement) ?? firstWindow(in: appElement)
        else { return nil }
        guard let axFrame = axFrame(of: element) else { return nil }
        let cocoa = cocoaFrame(fromAX: axFrame)
        let visibleFrames = NSScreen.screens.map(\.visibleFrame)
        let fallback = NSScreen.main?.visibleFrame ?? visibleFrames.first ?? .zero
        let screen = WindowTiling.preferredScreen(
            for: cocoa, among: visibleFrames, fallback: fallback)
        return Snapshot(element: element, frame: cocoa, screen: screen)
    }

    static func write(_ frame: CGRect, to element: AXUIElement) -> Bool {
        let ax = axFrame(fromCocoa: frame)
        setAXSize(ax.size, on: element)
        setAXPoint(ax.origin, on: element)
        return setAXSize(ax.size, on: element)
    }

    private static func focusedWindow(in app: AXUIElement) -> AXUIElement? {
        axElement(app, attribute: kAXFocusedWindowAttribute as CFString)
    }

    private static func firstWindow(in app: AXUIElement) -> AXUIElement? {
        var value: AnyObject?
        guard AXUIElementCopyAttributeValue(app, kAXWindowsAttribute as CFString, &value)
            == .success
        else { return nil }
        return (value as? [AXUIElement])?.first
    }

    private static func axElement(_ element: AXUIElement, attribute: CFString) -> AXUIElement? {
        var value: AnyObject?
        guard AXUIElementCopyAttributeValue(element, attribute, &value) == .success else {
            return nil
        }
        return value as? AXUIElement
    }

    private static func axFrame(of element: AXUIElement) -> CGRect? {
        guard let origin = axPoint(element, kAXPositionAttribute as CFString),
            let size = axSize(element, kAXSizeAttribute as CFString)
        else { return nil }
        return CGRect(origin: origin, size: size)
    }

    private static func axPoint(_ element: AXUIElement, _ attribute: CFString) -> CGPoint? {
        var value: AnyObject?
        guard AXUIElementCopyAttributeValue(element, attribute, &value) == .success,
            CFGetTypeID(value as CFTypeRef) == AXValueGetTypeID()
        else { return nil }
        var point = CGPoint.zero
        guard AXValueGetValue(value as! AXValue, .cgPoint, &point) else { return nil }
        return point
    }

    private static func axSize(_ element: AXUIElement, _ attribute: CFString) -> CGSize? {
        var value: AnyObject?
        guard AXUIElementCopyAttributeValue(element, attribute, &value) == .success,
            CFGetTypeID(value as CFTypeRef) == AXValueGetTypeID()
        else { return nil }
        var size = CGSize.zero
        guard AXValueGetValue(value as! AXValue, .cgSize, &size) else { return nil }
        return size
    }

    @discardableResult
    private static func setAXPoint(_ point: CGPoint, on element: AXUIElement) -> Bool {
        var point = point
        guard let encoded = AXValueCreate(.cgPoint, &point) else { return false }
        return AXUIElementSetAttributeValue(
            element, kAXPositionAttribute as CFString, encoded) == .success
    }

    @discardableResult
    private static func setAXSize(_ size: CGSize, on element: AXUIElement) -> Bool {
        var size = size
        guard let encoded = AXValueCreate(.cgSize, &size) else { return false }
        return AXUIElementSetAttributeValue(
            element, kAXSizeAttribute as CFString, encoded) == .success
    }

    private static var primaryHeight: CGFloat {
        NSScreen.screens.first { $0.frame.origin == .zero }?.frame.height
            ?? NSScreen.screens.map(\.frame.maxY).max() ?? 0
    }

    private static func cocoaFrame(fromAX ax: CGRect) -> CGRect {
        CGRect(
            x: ax.origin.x,
            y: primaryHeight - ax.origin.y - ax.height,
            width: ax.width,
            height: ax.height)
    }

    private static func axFrame(fromCocoa cocoa: CGRect) -> CGRect {
        CGRect(
            x: cocoa.origin.x,
            y: primaryHeight - cocoa.origin.y - cocoa.height,
            width: cocoa.width,
            height: cocoa.height)
    }
}
```

- [ ] **Step 3: Compile**

Run: `make`

Expected: BUILD SUCCEEDED.

- [ ] **Step 4: Commit**

```bash
git add Mote/Features/WindowTiling/Service/FrontmostWindowRunner.swift
git commit -m "$(cat <<'EOF'
feat: read and write the frontmost window frame via Accessibility

Keep Cocoa visibleFrame math in the tiling model by converting AX's top-left coordinates at the I/O boundary.
EOF
)"
```

---

### Task 4: Coordinator, defaults, AppCore

**Files:**
- Create: `Mote/Features/WindowTiling/UI/WindowTilingCoordinator.swift`
- Modify: `Mote/App/AppCore.swift`

**Interfaces:**
- Consumes: `WindowTiling.state/moved/resized/rect`, `FrontmostWindowRunner.read/write`, `HotKeyManager.setBinding`, `HotKeyManager.conflictOwner`, `HotKeyBinding.combo`, `KeyShortcut.init(carbonKeyCode:carbonModifiers:)`, `Permissions.ensureAccessibility()`, `kVK_LeftArrow` / `kVK_RightArrow`
- Produces:
  - `WindowTilingCoordinator.move()` and `.resize()`
  - `WindowTilingCoordinator.installDefaultBindings(into: HotKeyManager)`
  - UserDefaults key `windowTiling.defaultsInstalled` (Bool)
  - `AppCore` owns `windowTilingCoordinator`; after `hotKeys.start()` install defaults then set `onMoveWindow` / `onResizeWindow`

- [ ] **Step 1: Implement the coordinator**

```swift
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
```

- [ ] **Step 2: Wire `AppCore`**

Add with the other coordinators:

```swift
    @ObservationIgnored private(set) lazy var windowTilingCoordinator = WindowTilingCoordinator()
```

Assign closures before `hotKeys.start()` so a chord cannot fire with nil handlers; call `installDefaultBindings` after `start()` so `setBinding` registers on a live `HotKeyCenter`:

```swift
            hotKeys.onMoveWindow = { [weak self] in self?.windowTilingCoordinator.move() }
            hotKeys.onResizeWindow = { [weak self] in self?.windowTilingCoordinator.resize() }
            hotKeys.start()
            windowTilingCoordinator.installDefaultBindings(into: hotKeys)
```

Place the two assignments next to the existing `onTogglePalette` assignment.

- [ ] **Step 3: Build**

Run: `make`

Expected: BUILD SUCCEEDED.

- [ ] **Step 4: Commit**

```bash
git add Mote/Features/WindowTiling/UI/WindowTilingCoordinator.swift Mote/App/AppCore.swift
git commit -m "$(cat <<'EOF'
feat: tile the frontmost window from Move and Resize hotkeys

Gate on Accessibility, run TinyWin's cycle, and seed ⌃⌥← / ⌃⌥→ once when those chords are free.
EOF
)"
```

---

### Task 5: Settings recorders

**Files:**
- Modify: `Mote/Features/Settings/Panes/GeneralSettingsView.swift` (Global Shortcuts section)

**Interfaces:**
- Consumes: `HotKeyAction.moveWindow`, `HotKeyAction.resizeWindow`, existing `ShortcutRecorder`
- Produces: two recorders labeled Move Window and Resize Window in the same Global Shortcuts section as App Launcher

- [ ] **Step 1: Extend the Global Shortcuts section**

Replace the single-recorder section with:

```swift
            Section {
                SettingsRow(title: "App Launcher") {
                    ShortcutRecorder(action: .togglePalette)
                }
                SettingsRow(title: "Move Window") {
                    ShortcutRecorder(action: .moveWindow)
                }
                SettingsRow(title: "Resize Window") {
                    ShortcutRecorder(action: .resizeWindow)
                }
            } header: {
                Text("Global Shortcuts")
            } footer: {
                Text(
                    "Launcher summons the palette. Move and Resize tile the frontmost window (full height; 1/3, 1/2, 2/3, or full width). Quit TinyWin if both apps fight over ⌃⌥← / ⌃⌥→."
                )
                .font(.caption)
                .foregroundStyle(.secondary)
            }
```

- [ ] **Step 2: Build**

Run: `make`

Expected: BUILD SUCCEEDED.

- [ ] **Step 3: Commit**

```bash
git add Mote/Features/Settings/Panes/GeneralSettingsView.swift
git commit -m "$(cat <<'EOF'
feat: expose Move Window and Resize Window in General settings

Let the existing shortcut recorder rebind or clear the tiling chords.
EOF
)"
```

---

### Task 6: Docs, attribution, manual sweep notes

**Files:**
- Create: `docs/features/window-tiling.md`
- Modify: `docs/architecture.md`, `docs/features/hotkeys.md`, `docs/README.md`, `docs/testing.md`, `AGENTS.md`, `README.md`, `NOTICE.md`, `website/content/docs/reference/shortcuts.md`, `website/content/docs/reference/hotkeys.md`
- Modify: `docs/superpowers/specs/2026-09-11-window-tiling-design.md` status to implemented when this task finishes

**Interfaces:** none

- [ ] **Step 1: Write `docs/features/window-tiling.md`**

Must open with `## Invariants`. Include: cycle rules from the spec; coordinator owns policy; runner is I/O only; Model is AppKit-free; defaults key `windowTiling.defaultsInstalled`; quit TinyWin if Carbon conflicts; MIT attribution pointer to `NOTICE.md`.

- [ ] **Step 2: Patch the other docs**

- `docs/architecture.md` Features/ line: add `WindowTiling/`.
- `docs/features/hotkeys.md`: built-ins are App Launcher, Move Window, Resize Window. Move/Resize default to ⌃⌥← / ⌃⌥→ when free. Using them calls `Permissions.ensureAccessibility()`.
- `docs/testing.md` Hotkeys sweep: add “⌃⌥→ resizes the frontmost window through 1/3–1/2–2/3–full; ⌃⌥← moves the same size right→center→left; 1/3 flush right then Resize is full screen; full screen then Move is a no-op; beep without Accessibility.”
- `README.md`: one bullet — window tiling via ⌃⌥← / ⌃⌥→.
- `NOTICE.md` add:

```markdown
## Window tiling geometry (TinyWin / Rectangle)

`Mote/Features/WindowTiling/Model/WindowTiling.swift` is adapted from TinyWin, a personal fork of
Rectangle by Ryan Hanson, which is based on Spectacle by Eric Czarny. That geometry is MIT-licensed.
See <https://github.com/rxhanson/Rectangle>. Mote as a whole remains AGPL-3.0.
```

- `website/content/docs/reference/shortcuts.md`: add an **Outside the palette** table for ⌃⌥← Move and ⌃⌥→ Resize, noting they are rebindable in Settings → General.
- `website/content/docs/reference/hotkeys.md`: do not claim Mote ships with nothing bound. Palette stays unbound; Move/Resize seed TinyWin’s chords once. If you touch the “what can take a shortcut” list, delete the stale “30 window commands” Tinycast leftover rather than restoring those features.

- [ ] **Step 3: Full verification**

```sh
./Scripts/run-tests.sh
./Scripts/lint.sh
grep -rln 'import AppKit\|import SwiftUI\|import Cocoa' Mote/Features/*/Model/
make
```

Expected: harnesses pass; lint clean; grep empty; BUILD SUCCEEDED.

Manual (Debug `Mote Dev.app`): grant Accessibility; ⌃⌥→ / ⌃⌥← on a Finder window; Settings recorders; quit TinyWin if both are installed.

- [ ] **Step 4: Commit**

```bash
git add docs AGENTS.md README.md NOTICE.md website/content/docs/reference/shortcuts.md website/content/docs/reference/hotkeys.md
git commit -m "$(cat <<'EOF'
docs: document window tiling and credit Rectangle/TinyWin

Keep the feature invariants next to the code and the MIT notice next to the copied geometry.
EOF
)"
```

---

## Spec coverage (self-review)

| Spec requirement | Task |
| --- | --- |
| ⌃⌥→ resize / ⌃⌥← move cycle | 1 (math), 4 (dispatch) |
| Full height; 1/3 1/2 2/3 full | 1 |
| 1/3 right → full; move no-op on full; center 1/3 → 2/3 right | 1 tests |
| No palette rows / new Settings tab | 5 only adds General recorders |
| Model AppKit-free + harness | 1 |
| Runner I/O only; coordinator policy | 3, 4 |
| `HotKeyAction` keys and built-ins | 2 |
| Defaults once, no steal | 4 `installDefaultBindings` |
| Accessibility + beep | 4 |
| NOTICE / AGPL | 6 |
| No TinyWin repo edits | Global constraint |
| Docs listed in spec | 6 |

Type names throughout: `WindowTileSize`, `WindowTileAlign`, `WindowTileState`, `WindowTiling`, `FrontmostWindowRunner`, `WindowTilingCoordinator`.
