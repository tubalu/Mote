// Single source of truth for links and metadata used across the site.

export const site = {
  name: "Mote",
  tagline: "The essentials, without the bloat.",
  repo: "https://github.com/tubalu/Mote",
  url: "https://github.com/tubalu/Mote",
  fallbackVersion: "v0.1.0",
  platform: "macOS 26+",
  license: "AGPL-3.0",
  licenseUrl: "https://github.com/tubalu/Mote/blob/main/LICENSE",
} as const;

export const hero = {
  eyebrow: "Native macOS launcher",
  headline: "Everything on your Mac. One keystroke away.",
  sub: "A tiny, native launcher. No Electron. No account. No telemetry.",
} as const;

export const nav = [
  { label: "Gallery", href: "/#gallery" },
  { label: "Features", href: "/#features" },
  { label: "Docs", href: "/docs" },
  { label: "Install", href: "/#install" },
] as const;

export const quarantineCommand =
  'xattr -dr com.apple.quarantine "/Applications/Mote.app"';

export const stats = [
  { value: "<3", unit: "MB", label: "On disk" },
  { value: "<100", unit: "MB", label: "Memory" },
  { value: "0", unit: "", label: "Dependencies" },
  { value: "0", unit: "", label: "Telemetry" },
] as const;
