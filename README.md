# Tsuki

Tsuki is a Chrome/Edge Extension for improving website themes and readability. It also provides an
optional, capability-scoped Agent Bridge for explicitly granted pages.

## Agent Bridge from a source checkout

Requirements: Node.js 18+, Chrome/Edge 116+, and the workspace dependencies installed with pnpm.

```bash
pnpm agent:skill:link
pnpm agent:start
```

Enter the broker's single-use pairing code in Tsuki's **Agent bridge** panel, then enable **Read
access** for the intended origin. Agent notes and page actions require separate per-origin grants.
Start a new Codex turn after linking so the skill is discovered.

The link command refuses to replace an existing `$CODEX_HOME/skills/tsuki-agent` path. Remove only a
link created by this checkout with:

```bash
pnpm agent:skill:unlink
```

The Agent Bridge intentionally excludes clicking, form filling, navigation, cookies, website
storage, process memory inspection, network interception, and arbitrary JavaScript. Its only page
actions are scrolling a referenced element into view and displaying a temporary highlight overlay.
