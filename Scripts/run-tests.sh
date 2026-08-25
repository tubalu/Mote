#!/bin/bash
# The test suite. There is no XCTest target: each harness compiles the shipped sources it guards,
# so a harness that stops compiling means a decision leaked out of a pure layer. See docs/testing.md.
#
# Never join a compile and its run with `&&`: `set -e` ignores a failure in a non-final AND-OR list
# member, which is how CI reported success over a harness that had not compiled since phase 10.

set -uo pipefail
cd "$(dirname "$0")/.." || exit 1

BIN="${TMPDIR:-/tmp}/mote-harness"
mkdir -p "$BIN"

failed=()
ran=0
only="${1:-}"

# `--index` merges each harness's compile command into .compile instead of running anything.
# xcodebuild never compiles the harnesses, so without this nothing in Tests/ resolves in an editor.
# The source lists below are the only copy, which is why this lives here rather than in its own script.
emit_db=0
DB="${TMPDIR:-/tmp}/mote-compile-db.json"
if [ "$only" = "--index" ]; then
    emit_db=1
    only=""
    printf '[' > "$DB"
fi

# run <name> <source...> — compile the harness and run it, recording either kind of failure.
run() {
    local name=$1
    shift
    if [ -n "$only" ] && [ "$name" != "$only" ]; then return 0; fi
    ran=$((ran + 1))

    # Absolute paths throughout: sourcekit-lsp resolves the command itself and does not apply
    # `directory` to relative arguments, so a relative path there silently yields no index.
    if [ "$emit_db" -eq 1 ]; then
        local sources=()
        for source in "$@" "Tests/$name.swift"; do sources+=("$PWD/$source"); done
        [ "$ran" -gt 1 ] && printf ',' >> "$DB"
        printf '{"directory":"%s","command":"swiftc -swift-version 6 -sdk %s' \
            "$PWD" "$(xcrun --show-sdk-path --sdk macosx)" >> "$DB"
        printf ' %s' "${sources[@]}" >> "$DB"
        # Claim only the harness itself. The command still lists every shipped source it compiles, so
        # symbols resolve inside the harness — but claiming those sources here would hand them this
        # 3-file command instead of the app's, and `.compile` is last-wins.
        printf '","files":["%s/Tests/%s.swift"]}' "$PWD" "$name" >> "$DB"
        return 0
    fi

    if ! swiftc -swift-version 6 "$@" "Tests/$name.swift" -o "$BIN/$name" 2>&1; then
        printf '\033[31mFAIL\033[0m  %-22s did not compile\n' "$name"
        failed+=("$name")
        return 0
    fi
    if ! "$BIN/$name"; then
        printf '\033[31mFAIL\033[0m  %-22s assertion failed\n' "$name"
        failed+=("$name")
        return 0
    fi
    printf '\033[32mok\033[0m    %-22s\n' "$name"
}

L=Mote/Features/Launcher/Model
run fuzz-test              $L/SearchRelevance.swift
run ranking-test           $L/SearchRelevance.swift $L/LauncherRankingStore.swift
run scopes-test            $L/SearchScopes.swift
run app-name-test          Mote/Platform/AppDisplayName.swift
run favorites-test         $L/FavoriteSlots.swift
run palette-selection-test Mote/Features/PaletteRowIndex.swift
run appearance-test        Mote/Platform/Appearance.swift \
                           Mote/DesignSystem/Theme.swift \
                           Mote/Features/Settings/AppAppearance.swift
run palette-placement-test Mote/Platform/Appearance.swift \
                           Mote/DesignSystem/Theme.swift \
                           Mote/Palette/PalettePlacement.swift
run scroll-reveal-test     Mote/DesignSystem/Scrolling/SelectionReveal.swift
run hover-arming-test      Mote/Palette/HoverArming.swift \
                           Mote/Palette/PaletteState.swift \
                           Mote/Palette/PaletteMode.swift
run palette-escape-test    Mote/Palette/PaletteMode.swift \
                           Mote/Palette/PaletteEscapeAction.swift
run hotkey-test            Mote/Features/HotKeys/Model/DoubleTapModifier.swift \
                           Mote/Features/HotKeys/Model/DoubleTapDetector.swift \
                           Mote/Features/HotKeys/Model/HyperKey.swift \
                           Mote/Features/HotKeys/Service/KeyShortcut.swift \
                           Mote/Features/HotKeys/Model/HotKeyAction.swift \
                           Mote/Features/Launcher/Model/CommandID.swift \
                           Mote/Features/SystemActions/Model/SystemAction.swift
run callout-test           Mote/Platform/Appearance.swift \
                           Mote/DesignSystem/Theme.swift \
                           Mote/Features/HotKeys/UI/CalloutPlacement.swift
run icon-cache-test        Mote/Platform/Appearance.swift \
                           Mote/Platform/Images/IconCache.swift
run entry-icon-test        Mote/Platform/Appearance.swift \
                           Mote/Platform/Images/IconCache.swift
run system-action-test     Mote/Features/SystemActions/Model/SystemAction.swift
run volume-test            Mote/Features/SystemActions/Model/VolumeLevel.swift
run settings-history-test  Mote/Features/Settings/SettingsTab.swift \
                           Mote/Features/Settings/SettingsHistory.swift

if [ "$emit_db" -eq 1 ]; then
    printf ']\n' >> "$DB"
    [ -f .compile ] || echo '[]' > .compile
    python3 - .compile "$DB" <<'PY'
import json, sys

compile_path, harness_path = sys.argv[1], sys.argv[2]
existing = json.load(open(compile_path))
harnesses = json.load(open(harness_path))
kept = [e for e in existing if not any("/Tests/" in f for f in e.get("files") or [])]
json.dump(kept + harnesses, open(compile_path, "w"), indent=1)
print(f"{len(harnesses)} harness entries indexed into .compile")
PY
    exit 0
fi

if [ "$ran" -eq 0 ]; then
    echo "No harness named '$only'." >&2
    exit 2
fi

if [ ${#failed[@]} -gt 0 ]; then
    printf '\n%d harness(es) failed: %s\n' "${#failed[@]}" "${failed[*]}" >&2
    exit 1
fi
echo
if [ -n "$only" ]; then echo "$only passed."; else echo "All $ran harnesses passed."; fi
