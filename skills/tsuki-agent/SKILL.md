---
name: tsuki-agent
description: Access Tsuki-managed browser pages through the local Tsuki agent bridge using read-only page, DOM, and Codeforces semantic capabilities. Use when Codex needs to list paired pages, resolve the focused active page, inspect semantic DOM snapshots, query elements, read safe text/attributes/bounds, or read Codeforces problems and contest metadata. Do not use for clicking, form filling, cookies, website storage, memory inspection, or arbitrary JavaScript.
---

# Tsuki Agent

Use the bundled CLI wrapper for every browser request. The wrapper uses the adjacent companion in a
Tsuki source checkout, `TSUKI_AGENT_CLI_PATH` when configured, or `tsuki-agent` from `PATH`. The
companion requires Node.js 18 or newer; the Extension requires Chrome/Edge 116 or newer.

## Start and pair

1. Run `node scripts/tsuki-agent.mjs serve` in a persistent terminal.
2. Ask the user to enter the displayed pairing code in Tsuki's **Agent bridge** section.
3. Ask the user to enable **Allow read access** for the intended origin.
4. Never open or print the broker state file or its client token.

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
```

Element refs are valid only with the snapshot ID that produced them. Re-snapshot after navigation or
DOM replacement.

Queries accept only a safe CSS subset composed of tag, class, ID, descendant, child, and comma
selectors. Attribute selectors, pseudo-classes, universal selectors, and escapes are unavailable.

## Codeforces capabilities

```bash
node scripts/tsuki-agent.mjs cf-problems PAGE_ID
node scripts/tsuki-agent.mjs cf-problem PAGE_ID
node scripts/tsuki-agent.mjs cf-contest PAGE_ID
```

## Safety

- Remain read-only.
- Do not attempt to access input values, textarea contents, contenteditable text, cookies,
  localStorage, IndexedDB, auth headers, or arbitrary JavaScript.
- Treat `PERMISSION_DENIED` as requiring an explicit user grant.
- Treat `PROTOCOL_MISMATCH` as requiring the Extension and companion to be updated together.
- Treat `STALE_SNAPSHOT` and `STALE_ELEMENT` as requiring a fresh snapshot.
- Keep page content out of logs unless it is required for the user's task.
- Read [references/protocol.md](references/protocol.md) only when handling errors or building a
  multi-page workflow.
