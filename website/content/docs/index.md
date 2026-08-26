---
title: Getting started
description: What Tinycast is, and the few minutes that set it up.
---

Tinycast is a native macOS launcher that lives in the menu bar. Press a shortcut, a palette floats
in over whatever you were doing, you type, and it gets out of the way.

It is around 3 MB on disk and stays under 100 MB of memory, because it is SwiftUI and AppKit with
zero third-party dependencies. There is no Electron, no account, no sign-in and no telemetry.

## Set it up

Tinycast walks you through this the first time it launches, but here it is in full.

### 1. Record a shortcut

**Tinycast ships with no shortcut bound.** Nothing happens until you pick one, which is deliberate —
a launcher that claims a chord you were already using is a bad neighbour.

Open **Settings → General → Global Shortcuts** and click the **App Launcher** field, then press the
combination you want. <kbd>⌥</kbd><kbd>Space</kbd> is a common choice, but it is yours to pick.

You can also bind a **double-tapped lone modifier** — press and release <kbd>⌘</kbd> twice quickly,
with no other key. See [Hotkeys](/docs/reference/hotkeys) for the exact timings.

### 2. Grant Accessibility, when you need it

Accessibility is the **only** permission Tinycast ever asks for, and only when you first use
something that needs it — Hyper Key, double-tap modifiers, or certain system actions.

The launcher itself needs nothing. See [Permissions](/docs/permissions).

## The first thing to learn

Everything happens in one window. Type to search, <kbd>↵</kbd> to act, <kbd>⌘</kbd><kbd>K</kbd> to
see every other action for whatever is selected, <kbd>⎋</kbd> to leave.

Next: [the palette](/docs/palette), or [install it](/docs/install) if you haven't yet.
