# Testing and verification

How to check that a change holds up. Mote has no XCTest target and no UI tests: the automated half
is a set of standalone harnesses, and the manual half is the sweep at the bottom of this file.

## Definition of done

The mechanical bar, in one place so it cannot drift. All five pass before a change is finished.

| Check | Command |
| --- | --- |
| The harnesses | `./Scripts/run-tests.sh` |
| Lint | `./Scripts/lint.sh` |
| Pure-layer purity | `grep -rln 'import AppKit\|import SwiftUI\|import Cocoa' Mote/Features/*/Model/` |
| A clean build | `xcodebuild … -configuration Debug CODE_SIGNING_ALLOWED=NO`, zero **new** warnings |
| Docs still true | any doc your change made wrong, fixed in the same commit |

CI runs the first two and does not build the app at all — so the build, the purity grep and the docs
are on you. Each is expanded below; the manual sweep at the end of this file is the sixth, judged by
what you touched.

## The harnesses

```sh
./Scripts/run-tests.sh              # all of them
./Scripts/run-tests.sh calc-test    # just one, while iterating
```

The script is the **only** place the harness set is written down — CI runs exactly this, so the two
cannot drift. Adding a harness means adding one `run` line.

Each harness compiles the **shipped sources** it guards rather than a copy of them, which is what makes
the pure-layer boundary real: a harness that stops *compiling* means AppKit or SwiftUI has leaked into a
`Model/` folder, or an effect has leaked into a decision. That is a more common failure than a broken
assertion, and it is the more important one.

A harness also runs in your own login session against the real system, with no sandbox and no fixture
world, so it must never mutate state the machine shares with the apps you use.

Never join a compile to its run with `&&` in a `set -e` script. `set -e` is specified to ignore a
failing command in a non-final AND-OR list member, so `swiftc … && /tmp/x` swallows a compile error and
the script sails on. CI reported success over a harness that had not compiled for twenty-five phases
because of exactly this; `run-tests.sh` keeps the two steps separate and records both kinds of failure.

### What to run when

If a change touches anything in the right column, the harness on the left is mandatory.

| Harness | Guards |
| --- | --- |
| `fuzz-test` | `Launcher/Model/SearchRelevance.swift` |
| `ranking-test` | `Launcher/Model/LauncherRankingStore.swift` |
| `scopes-test` | `Launcher/Model/SearchScopes.swift` |
| `app-name-test` | `Platform/AppDisplayName.swift` — every path that names a scanned bundle |
| `favorites-test` | `Launcher/Model/FavoriteSlots.swift` |
| `palette-selection-test` | `Features/PaletteRowIndex.swift` |
| `palette-placement-test` | `DesignSystem/Theme.swift`, `Palette/PalettePlacement.swift` |
| `hover-arming-test` | `Palette/HoverArming.swift`, `PaletteState`, `PaletteMode` |
| `palette-escape-test` | `Palette/PaletteEscapeAction.swift` |
| `hotkey-test` | `HotKeys/Model/DoubleTapModifier.swift`, `DoubleTapDetector.swift`, `HyperKey.swift`, `HotKeyAction.swift`, `Service/KeyShortcut.swift`, and the command→action mapping in `Launcher/Model/CommandID.swift` |
| `callout-test` | `DesignSystem/Theme.swift`, `HotKeys/UI/CalloutPlacement.swift` |
| `icon-cache-test` | `Platform/Images/IconCache.swift` |
| `entry-icon-test` | `EntryIcon` — that each case draws, caches and prints apart from the others |
| `system-action-test` | `SystemActions/Model/SystemAction.swift` |
| `volume-test` | `SystemActions/Model/VolumeLevel.swift` |
| `settings-history-test` | `Settings/SettingsTab.swift`, `SettingsHistory.swift` |
| `appearance-test` | `Platform/Appearance.swift`, `DesignSystem/Theme.swift`, `AppAppearance` |
| `scroll-reveal-test` | `DesignSystem/Scrolling/SelectionReveal.swift` |

A harness that passed before a change passes after it. There is no "I'll fix it next commit" and no
commenting out a case. If a change genuinely invalidates an assertion, the assertion is rewritten in the
same commit with the reason in the message.

### Purity checks

The layering rule reduces to one grep, and it must return nothing:

```sh
grep -rln 'import AppKit\|import SwiftUI\|import Cocoa' Mote/Features/*/Model/
```

Beyond the imports, the injected-environment half is not mechanically checkable, so it is worth an eye
when touching a pure file:

- `HotKeys/Model/DoubleTap*` still take the clock as a parameter
- `Features/PaletteRowIndex.swift` still imports Foundation alone, despite living under `Features/`

## Build and size checks

A clean build is part of the bar; CI does not build the app, so this is on you.

```sh
xcodegen generate                 # only after editing project.yml
xcodebuild build -project Mote.xcodeproj -scheme Mote -configuration Debug \
  CODE_SIGNING_ALLOWED=NO
xcodebuild build -project Mote.xcodeproj -scheme Mote -configuration Release \
  CODE_SIGNING_ALLOWED=NO
find ~/Library/Developer/Xcode/DerivedData -name "Mote*.app" -maxdepth 6 -print -quit
```

- Zero **new** warnings. Pre-existing ones are not your problem; new ones are.
- No `@unchecked Sendable`, `nonisolated(unsafe)` or `assumeIsolated` added without a stated reason.
- The type-checker did not time out. `LauncherList.rows` already carries an explicit annotation for
  this reason; the fix for a timeout is an annotation, not a restructure.
- Release binary under **4 MB**, and under 2% growth for an ordinary change.

### Lint

```sh
./Scripts/lint.sh
```

SwiftLint owns the rules that catch defects, including the two checkable comment rules — the
100-character cap and the ban on stacked comment lines. Errors block; warnings do not. There is no
formatter, deliberately — the configuration and the measurements behind that are in
[development.md](development.md#formatting).

## Performance measurement

`Platform/Signposts.swift` emits eight intervals on the `com.mote.perf` subsystem: `AppCore.start`,
`AppIndex.scan`, `AppIndex.rank`, `PaletteWindowController.show`, `UninstallScanner.discover` and
`UninstallScanner.measure`, `FileSearchService.search`, and `Notes.search`. Open the Time Profiler or
`os_signpost` instrument in Instruments and filter to that subsystem; nothing needs recompiling.

Run the real Spotlight-backed file-search benchmark separately from the deterministic harnesses:

```sh
swiftc -O -swift-version 6 Mote/Platform/Signposts.swift \
    Mote/Features/Launcher/Model/SearchRelevance.swift \
    Mote/Features/FileSearch/Model/*.swift \
    Mote/Features/FileSearch/Service/FileSearchService.swift \
    Tests/file-search-performance.swift -o /tmp/file-search-performance
/tmp/file-search-performance
```

Every query runs twice: once on the shipped rules and once with five extra user patterns, so the output
says what the ignore list itself costs rather than only what Spotlight does.

`Signposts.interval` owns an explicit `defer` around the wrapped work on purpose. The obvious spelling
leaks the interval when the work throws, because the `.end` emit is skipped on the throw path and the
instrument then shows an interval that never closes.

Measure before optimising, and measure the same way twice. For cold launch: quit fully, relaunch, time
it three times, take the median.

### Recorded baselines

Measured at the end of the 2026 refactor, on `main`. Useful as orders of magnitude, not as contracts.

| | Value |
| --- | --- |
| Release binary | 3,655,736 B (from 3,471,592 B at the start of the refactor) |
| Resident memory | 40–80 MB in normal use; the hard ceiling is 100 MB |
| `SpotlightNames` cache | 76 ms cold, 0.2 ms warm |
| `SettingsPaneScanner` warm scan | 0.014 ms (16.5 ms cold), 52 panes |
| Largest view / owner | `RootPaletteView` 662 lines, `AppCore` 284 lines |
| Comment density | 1,653 of 27,289 source lines (6.1%) |
| `palette-selection-test` | 111,684 assertions — a tripwire: a change in this count means the row-order model moved |
| `SnippetKeywordPolicy` match | 7 µs/keystroke at 50 keywords, 59 µs at 1,000 — the `lowercased()` is 0.09 µs of it |
| `ClipboardStore.pinnedItems` | 27–127 µs per uncached search, 1,000-row window — no cache earns its invalidation yet |
| `count items of trash` | 5,000 ms against a cold Finder on an *empty* Trash, 110 ms warm — why AppleScript is detached |

Launch time, allocation counts and RSS have never been captured as numbers. The signposts are in place,
so any of them can be taken from `main` whenever a change makes it worth knowing.

## Manual regression sweep

There is no UI test suite, so this is it. Run the core sweep for any change that touches the palette;
run the scoped section for whatever feature you touched. Budget about five minutes plus three per
section.

Run against the **Debug channel** (`Mote Dev.app`, `com.mote.app.dev`). It has its own prefs,
caches, TCC grants and login item, so this cannot disturb an installed copy.

### Core

- Palette hotkey opens the launcher; pressing it again closes it; Escape clears a non-empty query,
  then hides on a second press; clicking away closes it
- Reopening focuses the search field with an empty query, in the same position and at the same size
- Compact mode: typing expands it, and the search bar does **not** shift vertically during the swap
- With a CJK IME: the placeholder clears as soon as composition starts and the composing text never
  overlaps it; cancelling composition brings the placeholder back, and the list filters only once the
  candidate is committed — check on a second summon too, where first responder never moved
- Typing filters instantly; ↑/↓ move the highlight and scroll it into view without yanking the list
- ⌃N/⌃P move the highlight as ↓/↑ do; ⌃F/⌃B move the caret
- The highlight always sits on the row the footer pill describes
- Section headers appear in order: Favorites, Applications, System Settings, System Actions, Commands
- ⌘K opens the Actions menu; ↑/↓ move it, ↵ activates, Escape closes the menu rather than the palette
- While a menu is open, typing does **not** change the query and the caret is hidden
- Launching an app focuses it; escaping the palette returns focus to the app you came from
- No flash, flicker or reflow on open, and row metrics unchanged

### Launcher and icons

- Every installed app appears; Settings panes appear under System Settings; running apps show the dot
- Icons render with no placeholder flash on reopen, and Settings ▸ Applications scrolls without hitching
- An app removed since the last open drops out after a reopen
- Learned ranking still surfaces your habitual result for a short query

### Hotkeys

- The palette shortcut fires; a per-app shortcut toggles that app
- Recording captures a shortcut, and the old binding does not fire while recording
- A conflicting binding is rejected and names its current owner
- A double-tap binding fires; Hyper Key remaps and its status dot is green
- Every binding survives quit and relaunch

### System actions

- A confirmation-gated action (Restart, Quit All) confirms, showing the subject's own glyph
- Volume actions show the volume HUD; everything else shows the message pill
- Holding a bound hotkey does **not** stack dialogs

### Settings

- Every pane renders and the sidebar switches without flicker
- A feature switch takes effect in the launcher immediately; every setting survives relaunch

### Clean install

The realistic storage failure is a store that crashes on an absent file rather than starting empty.
Wipe the Dev channel and check that path directly:

```sh
rm -rf ~/Library/Caches/com.mote.app.dev
rm -rf "$HOME/Library/Application Support/com.mote.app.dev"
defaults delete com.mote.app.dev 2>/dev/null || true
tccutil reset Accessibility com.mote.app.dev 2>/dev/null || true
```

- Launches with every store directory absent — no crash, no hang; onboarding runs
- Palette opens and lists apps, System Settings panes and system actions
- **Every setting shows its intended default.** Walk the panes: this is what catches a broken
  absence-versus-`false` read
- Quit and relaunch: everything created above persisted
- Nothing was written outside `com.mote.app.dev/`. Channel isolation is not negotiable — a Dev build
  writing into the stable app's directory is a defect even though the data is disposable
