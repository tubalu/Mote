---
title: Install
description: Download Mote from GitHub Releases and clear quarantine once.
---

Mote needs **macOS 26 or later**.

## Download

Builds are published on the
[Releases page](https://github.com/tubalu/Mote/releases).

1. Download `Mote-<version>.dmg`
2. Open it and drag **Mote** to Applications
3. Clear quarantine once (self-signed build — macOS blocks the first open otherwise):

```bash
xattr -dr com.apple.quarantine "/Applications/Mote.app"
```

## Updating

Download the newer DMG from Releases and replace the app in Applications, then clear quarantine
again if macOS asks.

## Uninstalling

Move `Mote.app` to the Trash. To remove settings and caches:

```bash
rm -rf ~/Library/Application\ Support/com.mote.app
rm -rf ~/Library/Caches/com.mote.app
defaults delete com.mote.app 2>/dev/null || true
```
