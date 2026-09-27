# Window tiling

Arrow-key tiling, hosted in Mote. Full visible height; Tile lands on 1/2, 2/3 or full, and Move keeps
whatever width it finds.
Geometry is MIT (Rectangle / TinyWin / Spectacle) — see [NOTICE.md](../../NOTICE.md). Mote stays AGPL-3.0.

## Invariants

- **`WindowTilingCoordinator` owns policy.** Accessibility gate, beep, cycle, and one-time default
  chords live there. `FrontmostWindowRunner` is I/O only: AX read/write and Cocoa↔AX Y flip. Do not
  put cycle math in the runner.
- **`Model/WindowTiling.swift` is Foundation + CoreGraphics only** — no AppKit, no SwiftUI. The
  harness `window-tiling-test` compiles the shipped file.
- **Defaults seed once per flag.** `windowTiling.defaultsInstalled` gates ⌃⌥← Tile Left and ⌃⌥→ Tile
  Right. `windowTiling.moveShiftDefaultsInstalled` gates ⌃⇧← Move Left and ⌃⇧→ Move Right.
  `windowTiling.maximizeDefaultsInstalled` gates ⌃⌥↑ Maximize. Each action
  is installed only when it has no binding and no other Mote action owns the chord. Clearing a binding
  later does not re-steal it.
- **Quit TinyWin if both apps fight over ⌃⌥← / ⌃⌥→.** Carbon gives the chord to whoever registered
  first; two processes cannot share it.
- **Using Maximize, Tile or Move calls `Permissions.ensureAccessibility()`.** Untrusted, no window, or AX
  failure: beep and return. No HUD, no mover fallback chain.

## Cycle

Maximize fills the visible frame; already full stays full.

Tile walks one chain: left 1/2 ⇄ left 2/3 ⇄ right 2/3 ⇄ right 1/2. On the chain, → steps one place
right and ← one place left; each end stays put. Off the chain (full, center, 1/3, free-floating):
jump to **2/3** on the pressed edge.

Move keeps size and steps toward the pressed edge through center: right ⇄ center ⇄ left. Already on
that edge stays; full is a no-op.

Tolerance is `0.08` of screen width; the space threshold is `max(40, screen.width * 0.08)`.

## Wiring

`AppCore` owns one `WindowTilingCoordinator`. Closures `onMaximize` / `onTileLeft` / `onTileRight` /
`onMoveLeft` / `onMoveRight` are set before `hotKeys.start()`; `installDefaultBindings` runs after. Recorders sit in
Settings → General next to App Launcher — no palette rows, no `CommandID`, no extra Settings tab.
Tile Left persists as `hotkey.window.move` and Tile Right as `hotkey.window.resize` so existing
bindings keep firing.
