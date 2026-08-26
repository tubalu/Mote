---
title: Permissions
description: Accessibility is the only permission Tinycast requests, and only when you use a feature that needs it.
---

Tinycast asks for **one** permission: Accessibility. Nothing else is ever requested.

The app launcher itself works with no permission at all.

## Accessibility

macOS calls this "control your computer". In Tinycast it is what allows Hyper Key rewriting,
double-tap modifier detection, and a few system actions that drive other apps.

**Grant it in System Settings → Privacy & Security → Accessibility**, or from
**Settings → Permissions**, which shows the current status and opens the right pane for you.

### What needs it

| Feature                                             | Why                                             |
| --------------------------------------------------- | ----------------------------------------------- |
| [Hyper key](/docs/reference/hotkeys#hyper-key)      | Rewrites the physical key into a modifier chord |
| Double-tap modifier hotkeys                         | Detects the tap pattern                         |
| Some [system actions](/docs/launcher/system-actions) | e.g. Show Info in Finder via Apple Events      |

You are prompted the first time you use one of these, not at launch.

## Automation and Bluetooth

Two [system actions](/docs/launcher/system-actions) trigger their own system prompts the first time
you run them:

- **Show Info in Finder** drives Finder through Apple Events, raising the standard Automation prompt.
- **Toggle Bluetooth** raises the Bluetooth prompt.

Both are requested at first use of that specific action, never up front.
