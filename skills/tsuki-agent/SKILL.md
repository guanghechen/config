---
name: tsuki-agent
description: Access explicitly granted Tsuki-managed browser pages through the local agent bridge using safe page/DOM inspection, Tsuki-owned session notes, strictly allowlisted scroll/highlight actions, and Codeforces semantic capabilities. Use when Codex needs to inspect a granted page, retain scoped notes for the browser session, or reveal an element to the user. Do not use for clicking, form filling, navigation, cookies, website storage, process memory, network interception, or arbitrary JavaScript.
---

# Tsuki Agent

Use the bundled CLI wrapper for every browser request. The wrapper uses the adjacent companion in a
Tsuki source checkout, `TSUKI_AGENT_CLI_PATH` when configured, or `tsuki-agent` from `PATH`. The
companion requires Node.js 18 or newer; the Extension requires Chrome/Edge 116 or newer.

## Start and pair

1. Run `node scripts/tsuki-agent.mjs serve` in a persistent terminal.
2. Ask the user to enter the displayed pairing code in Tsuki's **Agent bridge** section.
3. Ask the user to enable **Read access** for the intended origin.
4. Request **Agent notes** or **Page actions** only when the task needs them.
5. Never open or print the broker state file or its client token.

Pairing codes are single-use. After an explicit unpair or a prolonged Extension disconnect, use the
newest code printed by the running broker.

## Select a page

1. Run `node scripts/tsuki-agent.mjs pages`.
2. Prefer an explicit `pageId` selected by URL/title.
3. Use `node scripts/tsuki-agent.mjs active` only for initial resolution.
4. Keep using the concrete `pageId`; never assume the focused tab remains the target.
5. When a request returns `PAGE_STALE`, list pages again and obtain the new page ID.
6. Treat `PAGE_NOT_FOUND` after a browser/service-worker restart the same way and list pages again.

## Read a page

```bash
node scripts/tsuki-agent.mjs describe PAGE_ID
node scripts/tsuki-agent.mjs snapshot PAGE_ID --limit 200
node scripts/tsuki-agent.mjs query PAGE_ID 'CSS_SELECTOR' --limit 50
node scripts/tsuki-agent.mjs text PAGE_ID SNAPSHOT_ID ELEMENT_REF
node scripts/tsuki-agent.mjs attributes PAGE_ID SNAPSHOT_ID ELEMENT_REF
node scripts/tsuki-agent.mjs bounds PAGE_ID SNAPSHOT_ID ELEMENT_REF
node scripts/tsuki-agent.mjs scroll PAGE_ID SNAPSHOT_ID ELEMENT_REF --block center
node scripts/tsuki-agent.mjs highlight PAGE_ID SNAPSHOT_ID ELEMENT_REF --duration 1500
```

Call `scroll` before `highlight` when the element is outside the viewport. A highlight tracks the
element across scrolling and resizing until its bounded duration expires.

Element refs are valid only with the snapshot ID that produced them. Re-snapshot after navigation or
DOM replacement.

Queries accept only a safe CSS subset composed of tag, class, ID, descendant, child, and comma
selectors. Attribute selectors, pseudo-classes, universal selectors, and escapes are unavailable.

## Session notes

Notes are stored by Tsuki in `chrome.storage.session`, never in website storage. Use `origin` scope
for notes shared by granted pages on one origin, or `page` scope for the complete page URL. Page
identity is an opaque HMAC; raw query and fragment values are never returned or stored with notes.

```bash
node scripts/tsuki-agent.mjs memory-list PAGE_ID page
node scripts/tsuki-agent.mjs memory-get PAGE_ID page KEY
node scripts/tsuki-agent.mjs memory-set PAGE_ID page KEY 'VALUE'
node scripts/tsuki-agent.mjs memory-delete PAGE_ID page KEY
```

## Codeforces capabilities

```bash
node scripts/tsuki-agent.mjs cf-problems PAGE_ID
node scripts/tsuki-agent.mjs cf-problem PAGE_ID
node scripts/tsuki-agent.mjs cf-contest PAGE_ID
```

## Safety

- Keep website data read-only. Memory writes affect only Tsuki-owned session notes.
- Page actions are limited to `scrollIntoView` and a temporary, pointer-free highlight overlay.
- Do not attempt to access input values, textarea contents, contenteditable text, cookies,
  localStorage, IndexedDB, auth headers, website memory, or arbitrary JavaScript.
- Treat `PERMISSION_DENIED` as requiring an explicit user grant.
- Treat `PROTOCOL_MISMATCH` as requiring the Extension and companion to be updated together.
- Treat `STALE_SNAPSHOT` and `STALE_ELEMENT` as requiring a fresh snapshot.
- Keep page content out of logs unless it is required for the user's task.
- Read [references/protocol.md](references/protocol.md) only when handling errors or building a
  multi-page workflow.
