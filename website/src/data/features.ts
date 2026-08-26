import type { IconName } from "../components/ui/feature-icons";

export type Feature = {
  icon: IconName;
  title: string;
  body: string;
  /** Deep link into the docs page that covers this feature. */
  href: string;
  // `wide` features span two columns in the bento grid.
  wide?: boolean;
};

// What Mote (Tinycast lite) ships — launcher surface only.
export const features: Feature[] = [
  {
    icon: "launch",
    title: "App launcher",
    body: "Fuzzy-search every app on your Mac and open it with a keystroke. Pin the ones you reach for, see what's already running, and quit an app without leaving the keyboard.",
    href: "/docs/launcher",
    wide: true,
  },
  {
    icon: "bolt",
    title: "System actions",
    body: "Lock, sleep, restart, volume, Bluetooth, Stage Manager, empty the Trash — bindable to a key.",
    href: "/docs/launcher/system-actions",
  },
  {
    icon: "globe",
    title: "System Settings",
    body: "Jump straight to a Settings pane from the palette.",
    href: "/docs/launcher/system-settings",
  },
  {
    icon: "keyboard",
    title: "Global & per-app hotkeys",
    body: "Record a shortcut to summon the palette, bind a key to any app to focus or hide it, or double-tap a lone modifier.",
    href: "/docs/reference/hotkeys",
  },
  {
    icon: "hyper",
    title: "Hyper key",
    body: "Turn Caps Lock or a right-side modifier into ⌃⌥⇧⌘ — a whole extra layer of shortcuts, shown as a single ✦.",
    href: "/docs/reference/hotkeys",
  },
  {
    icon: "alias",
    title: "Aliases",
    body: "Rename anything in the launcher. An alias matches as strongly as the real name, so “ps” can open Photoshop.",
    href: "/docs/launcher/aliases",
  },
  {
    icon: "inputSource",
    title: "Input source switching",
    body: "Switch the keyboard to a chosen source while the palette is open, and put it back when you leave.",
    href: "/docs/palette",
  },
  {
    icon: "appearance",
    title: "Light & Dark",
    body: "Follow macOS, or pin the app to Light or Dark. Same design either way — only the ink inverts.",
    href: "/docs/reference/settings",
  },
];
