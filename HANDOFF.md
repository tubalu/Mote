# Handoff — Mote: RAM footprint of the running Release build looks high, unconfirmed if it's growth or floor

**User instruction (verbatim):** `write a handoff in Mote project. i will start a new session.`

This file is documentation only — no importers, no API surface, no data schemas. It records an
**open, unfinished** investigation on top of the previous session's completed rename + RAM-trim
work (still preserved below, under "Prior work — completed").

## Goal

Determine whether Mote's actual installed app (`/Applications/Mote.app`, the Release build users
run day-to-day) is exceeding its own documented memory budget, and if so, whether that's a genuine
leak/growth pattern or just its normal steady-state floor — then fix it if it's the former.

`docs/testing.md` documents a budget of **40–80MB normal, 100MB ceiling**. The prior session
verified `Mote Dev.app` (a fresh Debug build) at ~59MB right after landing three RAM trims — solidly
within budget. This session measured the actual **Release** binary that's been running as a real
daily-driver process for ~6 days, and it came in well above the ceiling. Those are two different
binaries/build channels measured at two different points in the app's lifecycle, so the discrepancy
is not yet a contradiction — it needs a same-conditions re-check before concluding anything.

## Current progress — this session

Started from a cross-app comparison: the user asked to check RAM usage on a *different* project,
TinyWin (`/Users/yong/code/tinyWindow`, unrelated app), which led to establishing the correct
methodology before pointing it at Mote.

1. **Established the right metric first, on TinyWin.** Activity Monitor's "Memory" column and
   `ps`'s RSS column both count shared, read-only framework pages (AppKit, Foundation, Swift
   runtime) as if they belonged solely to the process — wildly inflating the apparent number. The
   correct figure is the kernel's own `Physical footprint` line from `vmmap -summary <pid>` (or the
   `footprint <pid>` CLI tool this repo's own `docs/testing.md` already uses). Formula, verified
   against TinyWin's numbers: **footprint = (sum of DIRTY column) + (sum of SWAPPED column)** across
   `vmmap -summary`'s region table. For TinyWin this was 17.4M dirty + 7104K swapped ≈ 24.3M, which
   matched the reported footprint exactly.
2. **Applied the same methodology to Mote.** Found the running process via `ps aux | grep -i mote`
   → PID 10664, `/Applications/Mote.app/Contents/MacOS/Mote`, launched ~6 days earlier. Ran
   `vmmap -summary 10664`:
   - Reported **`Physical footprint: 115.9M (peak 121.3M)`** — well above the 100MB ceiling.
   - Cross-checked the formula: dirty regions summed to 46.4M, swapped summed to 69.5M → 46.4 + 69.5
     = 115.9M. Matches exactly, so (unlike a separate false alarm on TinyWin) this is **not** a
     shared-page measurement artifact — it's real private+compressed memory attributable to Mote.
   - Biggest contributors in the region table: `MALLOC_SMALL` (heap) at 37.2M dirty + 19.2M swapped
     ≈ 56M; `CG image`, `CoreAnimation`, and `VM_ALLOCATE` each showing ~12–13M in the SWAPPED
     column (graphics/image memory that's been compressed out after sitting idle, consistent with
     the launcher's icon-rendering palette UI).
3. **Confirmed no dependency overlap with TinyWin.** Mote has zero SwiftPM dependencies (no
   `Package.resolved`, nothing in `Mote.xcodeproj`'s package references) — it implements its own
   global-hotkey handling natively in `Mote/Features/HotKeys/Service/` (`HyperKeyTap.swift`,
   `HotKeyCenter.swift`, etc.), unlike TinyWin which depends on MASShortcut. Not the cause of
   anything here, just answers a question that came up while comparing the two apps.

**What this does NOT yet tell us:** whether 115.9M is Mote's honest floor for a 6-day-old process
(compression naturally accumulates over uptime even for perfectly healthy apps — that's what the
SWAPPED column represents, not necessarily a leak) or whether it reflects real unbounded growth. A
single snapshot late in the process's life can't distinguish those two.

## What worked

- **Establishing ground truth on a different, simpler app first** (TinyWin) before trusting any
  number on Mote — caught that `ps`/Activity Monitor are the wrong tool before wasting time chasing
  a phantom problem on this codebase.
- **Checking the arithmetic, not just the headline number.** Verifying dirty+swapped summed to the
  reported footprint on both apps is what confirmed the TinyWin number was fake framework-page
  inflation while the Mote number is real.
- **Reading the existing HANDOFF.md before writing anything.** It already documents a memory budget
  (`docs/testing.md`) and a very recent verified-good number (~59MB, `Mote Dev.app`) — without that,
  115.9M would have looked alarming with no baseline; with it, there's a specific, falsifiable
  question to answer (see Next Steps) instead of a vague "is this too much?"

## What didn't work / open gap

- **One snapshot isn't enough.** `vmmap -summary` on a single already-running, 6-day-old process
  cannot tell you whether its memory grew there or started there. This needs a before/after
  fresh-launch comparison, which this session did not do (the process was already running when the
  request came in; killing a live daily-driver app mid-investigation without asking felt like the
  wrong call for someone else's session to make unilaterally).
- **Debug-build verification (59MB) and this Release-build measurement (115.9M) are not
  apples-to-apples.** `Mote Dev.app` and `Mote.app` are different bundle IDs / build configs
  (see prior session's notes below) and were measured at different points in each process's
  lifetime. Don't cite the 59MB number as proof the 115.9M is a regression — it isn't proof either
  way yet.

## Next steps

1. **Get a fresh-launch baseline on the actual Release build**, same binary as production:
   ```bash
   osascript -e 'quit app "Mote"'      # or quit via the UI
   open -a /Applications/Mote.app
   sleep 30                             # let it settle past initial launch allocations
   PID=$(pgrep -f "Mote.app/Contents/MacOS/Mote")
   vmmap -summary "$PID" | grep "Physical footprint"
   ```
   - If fresh-launch footprint is already close to 100M+, that's Mote's real floor for what it does
     today — no leak, likely nothing further to do (maybe revisit whether the launcher UI/icon
     rendering is just inherently this heavy, but that's a design question, not a bug).
   - If fresh-launch footprint is much lower (well under the 100M ceiling, e.g. 40–80M matching the
     documented budget), that confirms growth over uptime — proceed to step 2.
2. **If growth is confirmed**, the region breakdown points at two candidates to check first, both
   already known quantities from the prior session's work (see table below):
   - `Mote/Platform/Images/IconCache.swift` — its `NSCache` caps were *lowered* last session
     (32→16MB, 8→4MB), but `NSCache.totalCostLimit` is an eviction hint, not a hard ceiling; confirm
     actual retained cost stays near those caps under real palette usage over hours, not just at
     launch.
   - Anything else holding onto rendered/decoded images or `CGImage`/`CoreAnimation` layers outside
     `IconCache`'s accounting — the SWAPPED-heavy graphics regions suggest something is allocating
     image/layer memory that isn't being freed even after going idle and getting compressed.
3. **Not started, and not urgent unless step 1 shows a real leak:** re-run the full
   `docs/testing.md` verification gate (`make build`, `./Scripts/run-tests.sh`, `./Scripts/lint.sh`)
   before landing any fix, per this repo's established convention.

### Key files for the next agent

| Path | Why |
| --- | --- |
| `docs/testing.md` | The 40–80MB normal / 100MB ceiling budget this investigation is measured against |
| `Mote/Platform/Images/IconCache.swift` | Primary suspect if growth is confirmed — recently-lowered `NSCache` caps, worth re-verifying they hold under real usage |
| `Mote/Features/Launcher/Model/LauncherRankingStore.swift` | Secondary candidate — lazy-load pattern from last session, unrelated to graphics memory but worth a glance if the heap (`MALLOC_SMALL`) number specifically is the one that grows |
| `Mote/App/AppCore.swift` | Composition root; where `appIndex.refresh()` deferral (last session's other RAM trim) lives |

---

## Prior work — completed (previous session, preserved for context)

Three commits on `main` (in order), from the session that did the Tinycast→Mote rename and three
RAM trims:

1. **`d6474ca` — Strip Tinycast to launcher-only surface and add Makefile for daily dev.**
   Removes AI, Calculator, Calendar, Clipboard, CustomCommands, Emoji, Extensions, FileSearch,
   Notes, Quicklinks, Snippets, Uninstall, Updates, WindowManagement, Backup, and the
   Raycast-runtime script tree.
2. **`f4b030e` — Rename Tinycast to Mote and trim idle RAM further.** Full rename (bundle ID
   `com.mote.app`/`.dev`, Xcode project/target/scheme, `Mote/` source folder, `@main` struct,
   internal `mote://` URL scheme, signing identity, every in-app string, build script, internal
   doc) plus three RAM trims:
   - Deferred `AppIndex.refresh()` to first palette open instead of running unconditionally at
     launch in `AppCore.start()`.
   - Lowered `IconCache`'s `NSCache` totalCostLimit caps: 32MB→16MB (full), 8MB→4MB (fitted/result).
   - Made `LauncherRankingStore` read its on-disk JSON lazily (`ensureLoaded()`) instead of
     synchronously in `init()`.
3. **`fc90e95` — Rename tinycast.icon to mote.icon.** Follow-up catching an Icon Composer resource
   folder the first rename's grep-based sweep missed (auto-discovered by XcodeGen from its folder
   path, never named in `project.yml`).

**Rename scope:** IN — `Mote/` source tree, `Mote.xcodeproj`/`project.yml`, `Makefile`,
`.swiftlint.yml`, `Scripts/*.sh`, `AGENTS.md`, most of `docs/`. OUT (deliberately, by design) —
`README.md`, `docs/features/*.md`, `website/`, `.github/`, `CONTRIBUTING.md`,
`CONTRIBUTOR_LICENSE_AND_FEEDBACK_AGREEMENT.md`, `SECURITY.md`, `NOTICE.md`, and
`Scripts/release-notes.sh` — these describe the real, currently-published Homebrew app/GitHub repo
(still named "tinycast"), which this rename never touched.

**Bundle-ID consequence:** the rename orphaned any existing Accessibility grant for "Tinycast Dev"
(TCC grants are keyed by bundle ID) — "Mote Dev" needed a fresh grant, which should then persist
across rebuilds via the stable self-signed identity (`Mote Self-Signed`, see `docs/signing.md`).

**What worked (prior session):** research before touching anything (a `/research-team` dispatch
correctly headed off a proposed Rust rewrite); splitting the rename into a written plan + Codex
execution + independent Claude review/verification (Codex's sandbox can't run `xcodebuild`, so
`make build`/tests/lint were always re-run unsandboxed); git's rename detection making a two-commit
split clean; asking before expanding scope, twice, rather than guessing how wide the rename should
go.

**What didn't work (prior session):** the plan itself had 3 bugs caught only because Codex stopped
and reported rather than working around them (`hasRanking(for:)` implicit-return break; a
sequencing bug that broke all 18 test harnesses for one task; a wrongly-scoped rename of
`BUNDLE_ID` in `release-notes.sh` that was reverted after review). A plain grep-based file sweep
missed the `mote://` URL-scheme literal and the `tinycast.icon/` folder — grep-only sweeps for a
rename are not exhaustive.
