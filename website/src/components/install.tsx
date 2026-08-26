"use client";

import { quarantineCommand, site } from "../data/site";
import { CopyCommand } from "./ui/copy-command";
import { Section } from "./ui/section";

export function Install() {
  return (
    <Section
      id="install"
      eyebrow="Get it"
      title="Download from GitHub."
      intro="Grab the latest DMG from Releases. There is no Homebrew cask for Mote."
    >
      <div className="mx-auto max-w-2xl">
        <p className="text-center text-body text-fg-muted">
          <a
            href={`${site.repo}/releases/latest`}
            target="_blank"
            rel="noreferrer"
            className="font-medium text-fg underline-offset-4 transition-colors hover:underline"
          >
            Download Mote →
          </a>
        </p>

        <div className="mt-6 rounded-xl border border-border p-4">
          <p className="text-body font-medium text-fg">After installing</p>
          <p className="mt-1.5 text-body text-fg-muted">
            Mote is self-signed — there is no paid Developer ID behind it — so macOS
            quarantines a download. Clear the flag once after dragging the app to
            Applications:
          </p>
          <div className="mt-3">
            <CopyCommand command={quarantineCommand} />
          </div>
        </div>

        <p className="mt-6 text-center text-small text-fg-subtle">
          <a
            href={`${site.repo}/releases`}
            target="_blank"
            rel="noreferrer"
            className="transition-colors hover:text-fg"
          >
            All releases on GitHub →
          </a>
        </p>
      </div>
    </Section>
  );
}
