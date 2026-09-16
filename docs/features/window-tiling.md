# Window tiling

TinyWin’s two-shortcut cycle, hosted in Mote. Full visible height; widths 1/3, 1/2, 2/3, or full.
Geometry is MIT (Rectangle / TinyWin / Spectacle) — see [NOTICE.md](../../NOTICE.md). Mote stays AGPL-3.0.

## Invariants

- **`WindowTilingCoordinator` owns policy.** Accessibility gate, beep, cycle, and one-time default
  chords live there. `FrontmostWindowRunner` is I/O only: AX read/write and Cocoa↔AX Y flip. Do not
  put cycle math in the runner.
- **`Model/WindowTiling.swift` is Foundation + CoreGraphics only** — no AppKit, no SwiftUI. The
  harness `window-tiling-test` compiles the shipped file.
- **Defaults seed once per pair.** `windowTiling.defaultsInstalled` gates ⌃⌥← Tile Left and ⌃⌥→ Tile
  Right. `windowTiling.moveShiftDefaultsInstalled` gates ⌃⇧← Move Left and ⌃⇧→ Move Right. Each action
  is installed only when it has no binding and no other Mote action owns the chord. Clearing a binding
  later does not re-steal it.
- **Quit TinyWin if both apps fight over ⌃⌥← / ⌃⌥→.** Carbon gives the chord to whoever registered
  first; two processes cannot share it.
- **Using Tile or Move calls `Permissions.ensureAccessibility()`.** Untrusted, no window, or AX
  failure: beep and return. No HUD, no mover fallback chain.

## Cycle

Tile pins the pressed edge. Already flush on that edge (or full): shrink Full → 2/3 → 1/2 → 1/3 →
full, still pinned. Not flush: jump to **2/3** on that edge. ⌃⌥← is the left-edge mirror of ⌃⌥→.

Move keeps size and steps toward the pressed edge through center: right ⇄ center ⇄ left. Already on
that edge stays; full is a no-op.

Tolerance is `0.08` of screen width; the space threshold is `max(40, screen.width * 0.08)`.

## Wiring

`AppCore` owns one `WindowTilingCoordinator`. Closures `onTileLeft` / `onTileRight` / `onMoveLeft` /
`onMoveRight` are set before `hotKeys.start()`; `installDefaultBindings` runs after. Recorders sit in
Settings → General next to App Launcher — no palette rows, no `CommandID`, no extra Settings tab.
Tile Left persists as `hotkey.window.move` and Tile Right as `hotkey.window.resize` so existing
bindings keep firing.
