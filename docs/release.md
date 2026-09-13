# Release

How a build reaches a user. The local development loop is in [development.md](development.md);
the signing identity itself is in [signing.md](signing.md).

## Packaging a DMG locally

```sh
./Scripts/build-dmg.sh            # -> build/Mote-<version>.dmg (version from project.yml)
./Scripts/build-dmg.sh 0.5.7      # -> build/Mote-0.5.7.dmg
```

It builds a Release `Mote.app` signed with `Mote Self-Signed` and packs it with an
`/Applications` symlink. Official per-channel releases are built by CI, below.

## Signing & Gatekeeper

Both local builds and CI releases sign with the same stable `Mote Self-Signed` identity, not an
Apple Developer ID — so macOS quarantines a downloaded DMG. Clear it once with
`xattr -dr com.apple.quarantine "/Applications/Mote.app"`. Full details in [signing.md](signing.md).
There is **no Homebrew cask** for Mote; distribution is GitHub Releases only.

## How the in-app updater consumes a release

Every release publishes two assets from one build: `Mote-<version>.dmg`, which people download by
hand, and `Mote-<version>.zip`. The
zip is produced with `ditto -c -k --keepParent --sequesterRsrc` — the only zip that leaves the code
signature verifiable, which matters because the updater refuses any bundle whose leaf certificate does
not match the running app's.

Three things a release must keep true, or the updater skips it:

- **It carries a `.zip` asset.** A DMG-only release is not installable and is not offered.
- **The tag parses as `vMAJOR.MINOR.PATCH` or `vMAJOR.MINOR.PATCH-beta.N`,** and agrees with the
  `prerelease` flag. `v0.9.7-sequoia` deliberately parses as neither, which is what keeps beta
  installs off the macOS 15 build.
- **It is not a draft.**


## Continuous integration

`.github/workflows/ci.yml` runs on every PR, on a `macos-26` runner with Xcode 26 (the same selection
step as the release workflow). One job, a merge gate; a new push cancels the in-flight run for the
same ref. Two steps, both of which shell out to a script rather than naming rules or harnesses in the
workflow, so neither can drift:

- **the harnesses** — `./Scripts/run-tests.sh`.
- **lint** — `./Scripts/lint.sh`, with `SWIFTLINT_REPORTER=github-actions-logging` so every violation
  is annotated **inline on the PR diff** instead of being buried in the log. It runs under
  `if: always()`, so a failing harness still surfaces the lint annotations in the same run. Warnings
  annotate only; **lint errors fail the job**, exactly as a local run does.

It does **not** run on pushes to `main`. `pull_request` builds the merge result, so re-running after a
merge would re-test content CI has already seen. A direct push to `main` therefore gets no run at all —
use **Actions → CI → Run workflow** if one ever needs checking.

There is **no `xcodebuild` step**: a Debug build costs minutes on every run and the release workflow
builds before it ships anyway, so CI keeps to the checks that finish in about a minute. The
consequence is that a change compiling nowhere still turns the PR green — **build locally before you
open one**. See [testing.md](testing.md#definition-of-done).

## Releasing

Pushing `vMAJOR.MINOR.PATCH` (or `vMAJOR.MINOR.PATCH-beta.N`) **starts the Release workflow**.
Pushing `main` alone does not — that would mint a DMG on every commit.

The two “Source code” zips on a tag page are GitHub’s repo archive. A real ship has
**`Mote-X.Y.Z.dmg` and `Mote-X.Y.Z.zip`**. Wait for the Actions run to attach them:

```sh
git tag vX.Y.Z
git push origin vX.Y.Z
gh run watch
```

Manual fallback (same workflow): **Actions → Release → Run workflow**, or

```sh
gh workflow run Release --field channel=stable --field version=X.Y.Z
```

Beta from the form still appends `-beta.N` (`N` = the Actions run number). A beta **tag** already
named `vX.Y.Z-beta.N` is used as-is.

Each channel builds a distinct app (`Mote.app` / `Mote Beta.app`) with its own bundle id, alongside
the local `Mote Dev.app`. It builds on a `macos-26` runner with Xcode 26. Secrets
`SIGNING_P12_BASE64` and `SIGNING_P12_PASSWORD` must be set ([signing.md](signing.md) §2) or the
run dies at import.

### Release notes

`Scripts/release-notes.sh` composes the release body, and CI runs it just before `gh release create`.
It is safe to run by hand against any tag — it only reads:

```sh
CHANNEL=beta TAG=v0.9.13-beta.61 ./Scripts/release-notes.sh /tmp/body.md /tmp/discord.md
```

The changelog itself comes from GitHub's own release-notes API, which lists every merged PR with its
author and number — so contributors are credited without anyone maintaining a `CHANGELOG.md`, and
without Conventional Commits. A tag-push run attaches assets to the tag you pushed; a form run lets
`gh release create` make the tag if it is missing. No version-bump commit is written back to `main`.

Two details the script exists for:

- **The previous tag is picked per channel.** Beta and stable tags interleave on `main` — the same
  commit can carry both — so "the previous release" is only ever right within one channel. A stable
  release therefore spans every beta since the last stable.
- **The body is split by `<!-- tinycast:install -->`.** Everything above it is the changelog;
  everything below is the install / quarantine text. The update
  window cuts at that marker — see [features/updates.md](features/updates.md). Full PR URLs are
  shortened to `#304`, which still autolinks on the web and fits a 460pt window.

The Discord announcement carries the same changelog, truncated to fit Discord's component limit, and
pings `@everyone`.


