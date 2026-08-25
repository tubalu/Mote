# Handoff — Tinycast lite strip + build tooling

**User instruction (verbatim):** `/handoff`

This file is documentation only — no importers, no API surface, no data schemas. It summarizes uncommitted work on branch `main` for the next agent.

## Goal

1. **Investigate reported ~96 GB RAM usage** and understand what Activity Monitor / `ps` actually show.
2. **Create a “lite” Tinycast** that keeps only the Settings launcher surface:
   - Applications
   - System Settings (pane jump)
   - System Actions
3. **Make daily dev simpler** — a `Makefile` with `make run`, `make test`, etc.
4. **Optional follow-up:** reduce idle RAM further (user reports **~54 MB** after lite strip; already within budget).

## Current progress

### Lite strip — done (uncommitted)

Large feature trees **deleted** and wiring **slimmed**. Remaining features under `Tinycast/Features/`:

| Feature | Role |
| --- | --- |
| `Launcher/` | App index, fuzzy search, favorites, visibility, aliases, settings panes |
| `SystemActions/` | Volume, appearance, Bluetooth, Hide Others, Quit All, etc. |
| `Settings/` | General, Applications, System Settings, System Actions, Permissions, About |
| `HotKeys/` | Global palette shortcut, per-app hotkeys, HyperKey, double-tap |
| `Onboarding/` | First-run flow (Raycast import removed) |

**Removed:** AI, Calculator, Calendar, Clipboard, CustomCommands, Emoji, Extensions, FileSearch, Notes, Quicklinks, Snippets, Uninstall, Updates, WindowManagement, Backup, `Scripts/raycast-runtime/`, emoji/currency generators, and most feature-specific tests/docs.

**Key rewires:**

- `Tinycast/App/AppCore.swift` — only launcher-related coordinators/stores; lazy palette/settings/onboarding
- `PaletteMode` — launcher only
- `HotKeyAction` / `CommandID` — slimmed to lite commands
- Settings sidebar — General, Applications, System Settings, System Actions, Permissions, About
- `Info.plist` — camera/calendar/URL schemes removed

### Makefile — done (uncommitted)

`Makefile` at repo root:

| Target | Purpose |
| --- | --- |
| `make` / `make build` | `xcodegen generate` + Debug build → **Tinycast Dev.app** |
| `make run` | Build and launch |
| `make test` | `./Scripts/run-tests.sh` |
| `make lint` | `./Scripts/lint.sh` |
| `make install` | Brew-installs `xcodegen` + `swiftlint`; prints **manual** steps only |
| `make identity` | Creates `Tinycast Self-Signed` cert |
| `make open` | Open Xcode project |

Sets `DEVELOPER_DIR` when `/Applications/Xcode.app` exists. Builds with `CODE_SIGNING_ALLOWED=NO` if no signing identity.

### RAM — analyzed

| Build | Idle-ish footprint |
| --- | --- |
| Full app (before strip) | ~139 MB `phys_footprint` (not 96 GB — that was virtual address space / VSZ) |
| Lite strip (user report) | **~54 MB** |

Project budget (`docs/testing.md`): **40–80 MB normal**, **100 MB hard ceiling**. Lite build is already compliant.

Largest discretionary pools when palette is open: `IconCache` (32 MB + 8 MB NSCache caps in `Tinycast/Platform/Images/IconCache.swift`), decoded CG images. At idle, icon cache is empty.

`AppCore.start()` eagerly runs `appIndex.refresh()` at launch (full app + Settings pane scan). Deferring until first palette open is the main remaining idle-RAM win (~2–8 MB) without removing features.

### Docs — partially updated

Updated: `AGENTS.md`, `README.md` (header/features), `docs/development.md`, `docs/architecture.md`, `docs/testing.md`, `docs/README.md`, some feature docs.

**Still stale** (mention removed features):

- `README.md` — Permissions / “Using it” sections still reference snippets, clipboard, custom commands
- `docs/ui.md`, `docs/testing.md` — clipboard, calculator, emoji, extensions copy
- `docs/development.md` — cache paths mention clipboard/calculator

### Tests

`Scripts/run-tests.sh` trimmed to **18 harnesses**.

On the user’s machine (Aug 2026), **14 passed / 4 failed to compile**:

```
ranking-test, hover-arming-test, icon-cache-test, entry-icon-test
```

Failure: `@Observable` macro — `ObservationMacros.ObservableMacro` / `swift-plugin-server` malformed response. Likely broken or incomplete Xcode install (DEVELOPER_DIR may point at Xcode.app that isn’t fully set up). Harnesses that compile only pure Model layers pass.

**Not verified on user machine:** full `xcodebuild` Debug/Release build, `./Scripts/lint.sh` (SwiftLint needs SourceKit/Xcode).

### Git state

- Branch: **`main`**
- **All lite + Makefile changes are uncommitted** (hundreds of modified/deleted files)
- User has **not** asked for a commit

## What worked

- **Feature deletion over shimming** — removing whole `Features/*` trees and rewiring `AppCore` is cleaner than feature flags.
- **Lazy coordinators** in `AppCore` — palette window and settings UI not created until needed.
- **RAM diagnosis** — use Activity Monitor “Memory” / `phys_footprint`, not `ps` VSZ. The 96 GB figure was virtual memory, not resident RAM.
- **`make install` as guidance-only** — prints manual Xcode/signing steps instead of failing opaquely.
- **Makefile `DEVELOPER_DIR` + unsigned fallback** — sensible defaults for local dev.

## What didn’t work

- **`sudo xcode-select -s /Applications/Xcode.app/Contents/Developer`** when Xcode.app is **not installed** — path doesn’t exist; only Command Line Tools at `/Library/Developer/CommandLineTools`.
- **Building with CLT alone** — Tinycast targets macOS 26 + Xcode 26 toolchain; CLT is insufficient.
- **Assuming 96 GB was real RAM** — misleading metric; actual footprint was ~139 MB full / ~54 MB lite.
- **Expecting all 18 harnesses to pass without a working Xcode** — four need `@Observable` macro expansion via `swift-plugin-server`.

## Next steps

### Blocker: install Xcode 26 (user machine)

1. Install **Xcode 26** from the App Store.
2. `sudo xcode-select -s /Applications/Xcode.app/Contents/Developer`
3. `sudo xcodebuild -runFirstLaunch`
4. `make identity` (one-time signing cert)
5. `make run` — build and launch Tinycast Dev
6. `make test` && `make lint` — verify green

### If continuing the lite work

1. **Doc cleanup** — scrub clipboard/snippets/calculator/extensions references from `README.md`, `docs/ui.md`, `docs/testing.md`, `docs/development.md`.
2. **Optional RAM trim** (user asked if 54 MB can go smaller; not implemented):
   - Defer `appIndex.refresh()` in `AppCore.start()` until first palette open
   - Lower `IconCache` caps (32→16 MB, 8→4 MB) — affects palette-open memory, not idle
   - Lazy-load `LauncherRankingStore` JSON
3. **Commit** — only when user explicitly asks; suggest message along the lines of: *Strip Tinycast to launcher-only surface and add Makefile for daily dev.*
4. **Re-run full test suite** after Xcode install; fix any compile/runtime regressions from the strip.

### Key files for the next agent

| Path | Why |
| --- | --- |
| `Tinycast/App/AppCore.swift` | Composition root — what starts at launch |
| `Tinycast/Features/Launcher/Service/AppIndex.swift` | App scan + index; `refresh()` at launch |
| `Tinycast/Platform/Images/IconCache.swift` | Icon memory caps |
| `Makefile` | Build entry point |
| `Scripts/run-tests.sh` | 18 harnesses |
| `project.yml` | XcodeGen source — run `xcodegen generate` after file changes |
| `docs/testing.md` | Memory budget + definition of done |

### Conversation context

Prior transcript: `.cursor/projects/Users-yong-code-tinycast/agent-transcripts/a4ef8bb8-a9bd-46d1-ab81-edae14d37372/a4ef8bb8-a9bd-46d1-ab81-edae14d37372.jsonl`

User’s latest RAM question was answered in chat: **54 MB is already good**; further reduction is optional with UX tradeoffs. Implementation was **not** started.
