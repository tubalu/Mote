# Security Policy

## Reporting a Vulnerability

Report privately through GitHub: **Security** tab → **Report a vulnerability**.

Include your macOS version, the Mote version, reproduction steps, and the impact.
Please don't disclose publicly until it's fixed.

We'll respond as quickly as we can and keep you posted.

## Supported Versions

Current release only. Update from
[Releases](https://github.com/tubalu/Mote/releases) before reporting.

## Scope

Of particular interest:

- **Accessibility (TCC)** — anything that widens what the grant enables.
- **Hotkeys** — the in-house hotkey stack.
- **Signing and distribution** — the DMG release chain.

Out of scope: builds being self-signed rather than notarized (known, see
[`docs/signing.md`](docs/signing.md)), and anything needing existing code execution or admin rights on
the machine.
