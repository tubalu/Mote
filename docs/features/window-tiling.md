# Window tiling

TinyWin’s two-shortcut cycle, hosted in Mote. Full visible height; widths 1/3, 1/2, 2/3, or full.
Geometry is MIT (Rectangle / TinyWin / Spectacle) — see [NOTICE.md](../../NOTICE.md). Mote stays AGPL-3.0.

## Invariants

- **`WindowTilingCoordinator` owns policy.** Accessibility gate, beep, cycle, and one-time default
  chords live there. `FrontmostWindowRunner` is I/O only: AX read/write and Cocoa↔AX Y flip. Do not
  put cycle math in the runner.
- **`Model/WindowTiling.swift` is Foundation + CoreGraphics only** — no AppKit, no SwiftUI. The
  harness `window-tiling-test` compiles the shipped file.
- **Defaults seed once.** `windowTiling.defaultsInstalled` is set the first time
  `installDefaultBindings` runs. ⌃⌥← Move and ⌃⌥→ Resize are installed only when that action has no
  binding and no other Mote action owns the chord. Clearing a binding later does not re-steal it.
- **Quit TinyWin if both apps fight over ⌃⌥← / ⌃⌥→.** Carbon gives the chord to whoever registered
  first; two processes cannot share it.
- **Using Move or Resize calls `Permissions.ensureAccessibility()`.** Untrusted, no window, or AX
  failure: beep and return. No HUD, no mover fallback chain.

## Cycle

Resize does not slide the window. Space on the right grows the right edge (1/3 → 1/2 → 2/3 → full)
when the left edge still lines up with a named slot. No space on the right shrinks from the left and
keeps the right edge (full → 2/3 → 1/2 → 1/3, flush right). A **1/3 window flush right** becomes
**full**. Full, or no space on either side, starts shrinking from **2/3 flush right**. Center 1/3
expanding right becomes **2/3 flush right**.

Move keeps size and cycles alignment: **right → center → left → right**. Full is a no-op.

Tolerance is `0.08` of screen width; the space threshold is `max(40, screen.width * 0.08)`.

## Wiring

`AppCore` owns one `WindowTilingCoordinator`. Closures `onMoveWindow` / `onResizeWindow` are set
before `hotKeys.start()`; `installDefaultBindings` runs after. Recorders sit in Settings → General
next to App Launcher — no palette rows, no `CommandID`, no extra Settings tab.
