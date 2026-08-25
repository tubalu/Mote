# Handoff — Mote (formerly Tinycast): finished RAM trims + full rename

**User instruction (verbatim):** `commit and handoff`

This file is documentation only — no importers, no API surface, no data schemas. It summarizes
work completed and committed on branch `main` today, for the next agent or session.

## Goal

Continuing from the prior session's handoff (lite feature-strip + Makefile, left uncommitted):

1. Finish the three optional RAM-reduction items that prior session identified but didn't implement.
2. Rename the product from "Tinycast" to "Mote," scoped to the app itself, its build tooling, and
   its genuinely internal docs — explicitly NOT the real published GitHub repo, Homebrew tap/cask,
   website, or legal docs, which stay "Tinycast" since this session didn't touch the actual release.
3. Commit everything and hand off.

## Current progress — all done, committed

Three commits on `main` (in order):

1. **`d6474ca` — Strip Tinycast to launcher-only surface and add Makefile for daily dev.** This is
   the prior session's lite-strip + Makefile work, committed today. Removes AI, Calculator,
   Calendar, Clipboard, CustomCommands, Emoji, Extensions, FileSearch, Notes, Quicklinks, Snippets,
   Uninstall, Updates, WindowManagement, Backup, and the Raycast-runtime script tree.
2. **`f4b030e` — Rename Tinycast to Mote and trim idle RAM further.** The full rename (bundle ID
   `com.mote.app`/`.dev`, Xcode project/target/scheme, `Mote/` source folder, `@main` struct,
   internal `mote://` URL scheme, signing identity, every in-app string, build script, and internal
   doc) plus the three RAM trims (below).
3. **`fc90e95` — Rename tinycast.icon to mote.icon.** A follow-up catching one Icon Composer
   resource folder the first rename's file sweep missed (auto-discovered by XcodeGen from its
   folder path, not named anywhere in `project.yml`, so a plain grep for known file paths didn't
   surface it).

**RAM trims (all 3 from the prior HANDOFF's "optional follow-up" list):**
- Deferred `AppIndex.refresh()` to first palette open — it was running unconditionally at launch
  in `AppCore.start()`, duplicating the re-scan `PaletteCoordinator.showPalette()` already does
  every time the palette opens in launcher mode.
- Lowered `IconCache`'s `NSCache` totalCostLimit caps: 32MB→16MB (full icon cache), 8MB→4MB
  (fitted/result-list cache).
- Made `LauncherRankingStore` read its on-disk JSON lazily (`ensureLoaded()`, gated by a
  `hasLoaded` flag) instead of synchronously in `init()`, which ran at every app launch before.

**Rename scope, precisely:**
- IN scope: `Mote/` (the whole source tree), `Mote.xcodeproj`/`project.yml`, `Makefile`,
  `.swiftlint.yml`, `Scripts/run-tests.sh`/`build-dmg.sh`/`format.sh`, `AGENTS.md`,
  `docs/architecture.md`, `docs/development.md`, `docs/README.md`, `docs/release.md` (partial),
  `docs/signing.md` (partial), `docs/standards.md`, `docs/testing.md`, `docs/ui.md` (one preserved
  link exception, see below).
- OUT of scope, deliberately untouched: `README.md`, `docs/features/*.md`, `website/`, `.github/`,
  `CONTRIBUTING.md`, `CONTRIBUTOR_LICENSE_AND_FEEDBACK_AGREEMENT.md`, `SECURITY.md`, `NOTICE.md`.
  Reason: these describe the real, currently-published Homebrew app and GitHub repo, which are
  still literally named "tinycast" — this session didn't touch the actual release, tap, cask, or
  Pages site, so their docs must keep saying "Tinycast" to stay accurate.
- Specific preserved literals inside otherwise-renamed files: the GitHub repo `abue-ammar/tinycast`,
  the Homebrew tap `abue-ammar/homebrew-tinycast` and cask names `tinycast`/`tinycast@beta`, the
  Pages URL `https://abue-ammar.github.io/tinycast/`, the `<!-- tinycast:install -->` marker, all
  four `AboutView.swift` `AboutLink` `detail`/`url` values for the "website"/"github" entries, and
  `docs/ui.md`'s one link `features/palette.md#the-placeholder-is-tinycasts-not-the-fields` (points
  at an out-of-scope, unrenamed heading). **`Scripts/release-notes.sh` was fully reverted to
  untouched** — every default in it (`REPO`, `DISPLAY_NAME`, `BUNDLE_ID`, `CASK`, `MARKER`)
  generates text describing the real current release, not this local rename.

**Verification, run directly (not just trusted from Codex):** `make build` → `** BUILD SUCCEEDED **`
for `Mote Dev.app`; `./Scripts/run-tests.sh` → all 18 harnesses pass; `./Scripts/lint.sh` → clean
(a handful of pre-existing warnings unrelated to naming). Confirmed running process footprint via
`footprint <pid>`: ~59 MB, within the 40–80 MB normal budget in `docs/testing.md`.

**Bundle-ID consequence:** the rename means any existing Accessibility grant for "Tinycast Dev" is
orphaned (TCC grants are keyed by bundle ID). Next launch of "Mote Dev" needs a fresh grant; it
should then persist across rebuilds as before, thanks to the stable self-signed identity
(`Mote Self-Signed` — see `docs/signing.md`, `make identity`).

## What worked

- **Research before touching anything.** A `/research-team` dispatch (planner, architect,
  docs-lookup, Explore, market-scout) established that the reported CLT-vs-Xcode build failure was
  just a missing Xcode.app install, not a fundamental toolchain gap — and that neither dropping the
  `@Observable` macro nor rewriting in another language was worth it. This correctly headed off a
  request to consider a Rust rewrite before any code was touched.
- **Splitting a big rename into a written plan + Codex execution + Claude review**, rather than one
  agent doing everything. `docs/superpowers/plans/2026-08-25-ram-trim-and-rename.md` is the full
  plan; Codex executed it task-by-task via the `codex-rescue` agent, stopping and reporting on every
  ambiguity or failure rather than guessing past it.
- **Verifying independently rather than trusting an agent's self-report.** Codex's sandbox cannot
  run `xcodebuild`/`make build` (it hits `sandbox-exec: sandbox_apply: Operation not permitted` —
  a nested-sandboxing restriction of its execution environment, unrelated to the actual toolchain).
  Running the same build/test/lint gate directly, unsandboxed, was the only way to get real
  pass/fail signal for anything touching `xcodebuild`.
- **git's automatic rename detection** made the two-commit split (lite-strip vs. rename) clean even
  though the underlying content was inseparable at the file level — staging the old `Tinycast/*`
  deletions alongside the new `Mote/*` untracked files let `git add` auto-detect ~156 renames by
  content similarity.
- **Asking before expanding scope**, twice: once before starting the rename at all (how wide should
  it go — app-only vs. whole-repo vs. display-name-only), and once when README.md's Install section
  turned out to describe the real published Homebrew app. Both times the answer changed what got
  touched in a way that would have been wrong to guess.

## What didn't work

- **My own plan had three real bugs**, each caught by Codex stopping rather than working around it:
  1. `hasRanking(for:)` — adding `ensureLoaded()` as a new first statement silently broke Swift's
     implicit single-expression return, needing an explicit `return`. (Codex hit a real compile
     error; Claude fixed it directly and updated the plan.)
  2. Sequencing — `Scripts/run-tests.sh`'s hardcoded `Tinycast/` paths weren't scheduled for fixing
     until Task 4, but Task 2's own harness-gate requirement ran before that, breaking all 18
     harnesses immediately after the folder move. Fixed by moving that specific fix earlier.
  3. `BUNDLE_ID` in `Scripts/release-notes.sh` — initially told Codex to rename this to
     `com.mote.app`, reasoning it was "an in-app identifier." Wrong: that script generates release
     notes for the real, currently-shipped release, same category as `REPO`/`CASK`/`MARKER` which
     were already correctly left alone. Caught during final review, reverted.
- **A plain grep-based file sweep isn't exhaustive.** Two things it missed entirely: an internal
  `mote://` URL-scheme literal (not caught until Codex's own authoritative sweep found it), and the
  `tinycast.icon/` Icon Composer folder (not caught until final post-commit review — it's
  auto-discovered by XcodeGen from its folder path, never named in `project.yml`).
- **Assuming "core docs" meant "safe to rename" was wrong for README.md and docs/features/*.md** —
  they describe the real shipped product's install instructions and reference real GitHub issues,
  not just this local dev build's identity.

## Next steps

Nothing blocking. Everything is built, tested, linted, and committed.

- **Grant Accessibility to "Mote Dev"** on next launch (see Bundle-ID consequence above).
- **Optional, not started:** the `website/` docs site and `docs/features/*.md` are still stale from
  the *original* lite-strip (they describe Calculator/Clipboard/Emoji/Snippets/etc., which no
  longer exist) — this was already flagged as pending in the prior session's handoff and remains
  untouched by design; today's rename deliberately didn't touch them either, for the separate
  external-reference reason above. If that cleanup is wanted, it's a distinct piece of work from
  today's rename.
- **Not evaluated:** whether to push `main` or open a PR — nothing in this session touched remote
  git state; all three commits are local only.

### Key files for the next agent

| Path | Why |
| --- | --- |
| `docs/superpowers/plans/2026-08-25-ram-trim-and-rename.md` | The full rename plan, with every exception and correction recorded in place — read this before touching naming again |
| `Mote/App/AppCore.swift` | Composition root — the deferred `appIndex.refresh()` lives in `start()` |
| `Mote/Features/Launcher/Model/LauncherRankingStore.swift` | The lazy-load pattern (`ensureLoaded()`) |
| `Mote/Platform/Images/IconCache.swift` | The two lowered cache caps |
| `Mote/Windows/About/AboutView.swift` | The four preserved external-link lines — don't rename these |
| `Scripts/release-notes.sh` | Fully untouched by design — describes the real release, not this rename |
| `docs/testing.md` | Memory budget (40–80MB normal, 100MB ceiling) + definition of done |
