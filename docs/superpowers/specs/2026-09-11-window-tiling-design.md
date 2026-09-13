# Window tiling in Mote (TinyWin cycle)

Date: 2026-09-11
Status: implemented

Mote becomes the daily-driver menu-bar app. TinyWin’s two-shortcut window cycle ships **inside Mote**.
The TinyWin git repo (`/Users/yong/code/tinyWindow`) stays a separate project. We do not merge git
histories, compile TinyWin.app into Mote, or take MASShortcut / Sparkle / Rectangle storyboards.

## Goal

From Mote, with Accessibility granted:

| Shortcut (default) | Action |
| --- | --- |
| ⌃⌥→ | **Resize** the frontmost window |
| ⌃⌥← | **Move** the frontmost window |

Behavior is the cycle already covered by TinyWin’s `TinyWinLayout` and `TinyWinCycleTests`. Windows
always fill the **visible height** of the current display. Widths are **1/3**, **1/2**, **2/3**, or
**full**.

Resize does not slide the window:

- Space on the right → grow the right edge: 1/3 → 1/2 → 2/3 → full (left edge stays put when it still
  lines up with a named slot).
- No space on the right → shrink from the left, keep the right edge: full → 2/3 → 1/2 → 1/3, flush
  right.
- A **1/3 window flush right** becomes **full screen**.
- Full screen, or no space on either side, starts shrinking from **2/3 flush right**.
- Center 1/3 expanding right becomes **2/3 flush right**.

Move keeps size and cycles alignment: **right → center → left → right**. Full screen is a no-op.

## Non-goals

- Palette rows, launcher `CommandID`s, or a new Settings tab for tiling.
- Rectangle snapping, ignore-app, URL actions, restore-previous-frame, size-limit HUD, display
  cycling, or the WindowMover chain.
- Changing Mote’s license (stays AGPL-3.0). MIT TinyWin/Rectangle geometry is copied in with
  attribution.
- Retiring or modifying the TinyWin repository in this work.

## Architecture

New feature folder `Mote/Features/WindowTiling/`, split the Mote way:

```
Model/   WindowTiling.swift     Foundation-only geometry (port of TinyWinLayout)
Service/ FrontmostWindowRunner.swift   AX frontmost window + visible frame + set position/size
UI/      WindowTilingCoordinator.swift  Accessibility gate, beep, calls model then runner
```

`Model/` must stay AppKit-free so a harness can compile the shipped file. Screen and window rects are
injected `CGRect`s (`CoreGraphics` is allowed; `import AppKit` is not).

`AppCore.shared` owns one `WindowTilingCoordinator`. `applicationDidFinishLaunching` still only calls
`AppCore.start()`. In `start()`, after `hotKeys.start()`:

1. Seed default bindings if needed (see below).
2. `hotKeys.onMoveWindow` / `hotKeys.onResizeWindow` close over the coordinator.

Views never call the runner. Confirmation is not used (tiling is not destructive).

### Hotkeys

Add two built-in `HotKeyAction` cases:

| Case | `defaultsKey` | Settings label |
| --- | --- | --- |
| `.moveWindow` | `hotkey.window.move` | Move Window |
| `.resizeWindow` | `hotkey.window.resize` | Resize Window |

Put both in `HotKeyAction.builtInActions` after `.togglePalette`. General settings grows two
`ShortcutRecorder`s next to the palette shortcut. Users can rebind or clear them like any other
chord, including double-tap modifiers.

`HotKeyManager.perform` dispatches the new cases through the new closures, same shape as
`onTogglePalette`.

Default chords (TinyWin’s) are installed **once**, only when:

- that action has no stored binding, and
- no other Mote action already owns ⌃⌥← / ⌃⌥→ (`conflictOwner`).

If the chord is taken, leave the action unbound; do not steal it. A UserDefaults flag
`windowTiling.defaultsInstalled` prevents re-prompting the defaults on later launches after the user
clears a binding.

If TinyWin.app is also running, both apps may fight over the same Carbon hotkeys. Document: quit
TinyWin when using Mote’s tiling.

### Permissions and effects

Each dispatch starts with `Permissions.ensureAccessibility()`. If still untrusted, beep and return
(existing Hyper Key / system-action pattern).

The coordinator owns the cycle: read frame → `WindowTiling.moved` / `.resized` → write frame.
`FrontmostWindowRunner` only does I/O:

1. Resolve the focused standard window via Accessibility (frontmost app’s focused window, else
   frontmost window).
2. Read its frame.
3. Resolve `NSScreen.visibleFrame` for the screen with the largest intersection; fall back to main.
4. Write a caller-supplied `CGRect` as position then size through AX.

On “no window” or AX failure: beep. Do not port TinyWin’s mover fallback chain or “Window size
limited” HUD. Apps with a large minimum size simply stay larger than the slot.

### Types (Model)

Rename for Mote; keep the math:

- `WindowTileSize`: `third`, `half`, `twoThirds`, `full` with `nextLarger` / `nextSmaller`
- `WindowTileAlign`: `left`, `center`, `right`
- `WindowTileState`
- `WindowTiling`: `state(of:in:)`, `resized(_:window:screen:)`, `moved(_:)`, `rect(for:in:)`

Tolerance and space threshold stay as in TinyWin (`0.08` width ratio; space threshold
`max(40, screen.width * 0.08)`).

## Tests and docs

New harness `Tests/window-tiling-test.swift` compiling `Mote/Features/WindowTiling/Model/WindowTiling.swift`.
It restates TinyWinCycleTests on a 1200×800 screen:

- full resize shrinks along the right edge to 2/3 → 1/2 → 1/3 → full
- left third expands toward full
- half move cycles right → center → left → right
- move leaves full unchanged
- center third expands to right two-thirds
- geometry round-trip for a right half

Add a `run` line in `Scripts/run-tests.sh`. `hotkey-test` already compiles `HotKeyAction`; new cases
must keep its switches exhaustive.

Update in the same change: `docs/features/window-tiling.md`, `docs/testing.md` (harness table),
`docs/architecture.md` (feature list), `docs/features/hotkeys.md` (built-in actions), README feature
bullet, `website/content/docs/reference/shortcuts.md`, `NOTICE.md` (Rectangle / TinyWin MIT
attribution).

## License

Copied geometry is MIT (Rectangle / TinyWin / Spectacle). Mote remains AGPL-3.0. `NOTICE.md` names
Ryan Hanson / Rectangle and this TinyWin port. Do not copy TinyWin files wholesale with Sparkle or
MASShortcut.

## Out of repo

No commits in `/Users/yong/code/tinyWindow` for this feature.
