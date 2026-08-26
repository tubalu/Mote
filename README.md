# Mote

A lite, native macOS menu-bar launcher — fuzzy app search, System Settings panes, system actions,
and global / per-app hotkeys. SwiftUI + AppKit, zero third-party dependencies.

<p align="center">
  <a href="LICENSE">
    <img alt="License: AGPL-3.0"
         src="https://img.shields.io/badge/License-AGPL--3.0-3DA639?style=flat"></a>
</p>

<p align="center">
  <img src="docs/screenshot.png" alt="Mote command palette" width="720">
</p>

Around **3 MB on disk** and **under 100 MB of RAM** — no Electron, no telemetry, no background
CPU churn.

## Features

- **App launcher** — fuzzy-search and launch anything, pin favorites, see what's running, quit an app
  or every app at once.
- **System Settings** — jump straight to a Settings pane.
- **System actions** — volume, appearance, Bluetooth, Hide Others, Quit All, and the rest, from the
  palette or a global hotkey.
- **Global hotkey** — one shortcut summons the palette from anywhere.
- **Per-app hotkeys** — bind a key to an app; press it to toggle (focus/hide).

## Permissions

**Accessibility** — needed for Hyper Key, double-tap modifiers, and a few system actions. You're
prompted when you first use a feature that needs it; grant access in **System Settings → Privacy &
Security → Accessibility**. The launcher itself needs nothing.

## Using it

1. Open **Settings → General** and record a global shortcut to summon the palette.
2. Press it anywhere → the palette floats in. Type to filter, **↵** to launch.
3. **↑/↓** move the selection; **Esc** dismisses.
4. **Settings → Shortcuts** — search an app and record a global shortcut to focus or hide it.

## Building from source

Requires **macOS 26+** and **Xcode 26**. First time:

```sh
make install   # brew tools + leftover manual steps
make identity  # once: self-signed cert for local TCC grants
```

Daily loop:

```sh
make           # Debug build → Mote Dev.app
make run       # build and launch
make CONFIG=Release build   # Release → Mote.app
make test
make lint
```

See **[docs/development.md](docs/development.md)** for toolchain and signing details.

## Attribution & license

Mote is based on code from [Tinycast](https://github.com/abue-ammar/tinycast) by Abue Ammar, trimmed
to a launcher-only surface. Both the original work and this modification are licensed under the
[GNU Affero General Public License v3.0](LICENSE) (AGPL-3.0).

See [NOTICE.md](NOTICE.md).
