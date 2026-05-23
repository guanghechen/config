---
name: playwright-cli
description: Automate browser interactions from the shell with the Microsoft Playwright CLI. Use when the user needs an agent to navigate pages, inspect snapshots, click or fill elements, capture screenshots/PDFs/videos/traces, debug Playwright tests, mock network requests, or extract page data without a full MCP browser loop.
allowed-tools: Bash(playwright-cli:*)
---

# Playwright CLI

Use `playwright-cli` for token-efficient browser automation from an agent session. Prefer it for deterministic page interaction and web test debugging. Use a browser MCP such as Playwright MCP or Chrome DevTools MCP only when the task needs rich persistent tool introspection, deep Chrome DevTools/performance analysis, or the user explicitly asks for MCP.

## Availability

Requires Node.js 18 or newer.

1. Check for the command first:

```bash
command -v playwright-cli
playwright-cli --version
```

2. If unavailable, check whether the current project already provides it:

```bash
npx --no-install playwright-cli --version
```

3. If neither works, ask before installing or downloading packages. The maintained npm package is `@playwright/cli`; the older `playwright-cli` package is deprecated. After approval, install or run it as:

```bash
npm install -g @playwright/cli@latest
# or one-shot without global install:
npx --yes --package @playwright/cli@latest playwright-cli --version
```

For multi-step browser work, prefer an installed `playwright-cli` binary or a project-local package because commands are run repeatedly against the same session. Do not use plain `npx playwright-cli`; it can resolve the deprecated package.

## Workflow

1. Open a browser, using a semantic session name for non-trivial work:

```bash
playwright-cli -s=checkout open http://localhost:3000
```

2. Take a snapshot and use refs such as `e15` for actions:

```bash
playwright-cli -s=checkout snapshot --depth=4
playwright-cli -s=checkout click e15
playwright-cli -s=checkout fill e8 "user@example.com" --submit
```

3. Snapshot after navigation or state-changing actions. Use screenshots only when visual layout, canvas, image rendering, or evidence matters.

4. Prefer element refs from snapshots. Use CSS selectors or Playwright locators when refs are missing or unstable:

```bash
playwright-cli click "#submit"
playwright-cli click "getByRole('button', { name: 'Submit' })"
```

5. Close sessions when done unless the user wants the browser left open:

```bash
playwright-cli -s=checkout close
```

## Command Map

Core:

```bash
playwright-cli open [url]
playwright-cli goto <url>
playwright-cli snapshot [ref] [--filename=file] [--depth=N] [--boxes]
playwright-cli click <ref-or-selector> [button]
playwright-cli dblclick <ref-or-selector> [button]
playwright-cli fill <ref-or-selector> <text> [--submit]
playwright-cli type <text>
playwright-cli press <key>
playwright-cli keydown <key>
playwright-cli keyup <key>
playwright-cli mousemove <x> <y>
playwright-cli mousedown [button]
playwright-cli mouseup [button]
playwright-cli mousewheel <dx> <dy>
playwright-cli hover <ref-or-selector>
playwright-cli drag <startRef> <endRef>
playwright-cli drop <ref> --path=<file>
playwright-cli drop <ref> --data="text/plain=value"
playwright-cli select <ref> <value>
playwright-cli upload <file>
playwright-cli check <ref>
playwright-cli uncheck <ref>
playwright-cli dialog-accept [prompt]
playwright-cli dialog-dismiss
playwright-cli resize <width> <height>
playwright-cli close
```

Open, attach, and profile options:

```bash
playwright-cli open --browser=chrome
playwright-cli open --browser=firefox
playwright-cli open --browser=webkit
playwright-cli open --browser=msedge
playwright-cli open [url] --headed
playwright-cli open --persistent
playwright-cli open --profile=<path>
playwright-cli open --config=file.json
playwright-cli attach --extension=chrome
playwright-cli attach --cdp=chrome
playwright-cli attach --cdp=msedge
playwright-cli attach --cdp=http://localhost:9222
playwright-cli attach <session-name>
playwright-cli detach
playwright-cli delete-data
```

Navigation, tabs, and sessions:

```bash
playwright-cli go-back
playwright-cli go-forward
playwright-cli reload
playwright-cli tab-list
playwright-cli tab-new [url]
playwright-cli tab-select <index>
playwright-cli tab-close [index]
playwright-cli -s=<name> <command>
playwright-cli list
playwright-cli close-all
playwright-cli kill-all
```

Artifacts and inspection:

```bash
playwright-cli screenshot [ref] [--filename=file]
playwright-cli pdf [--filename=file]
playwright-cli console [min-level]
playwright-cli requests
playwright-cli request <index>
playwright-cli eval <expression-or-function> [ref]
playwright-cli run-code <function-expression>
playwright-cli run-code --filename=file.js
playwright-cli tracing-start
playwright-cli tracing-stop
playwright-cli video-start [filename]
playwright-cli video-chapter <title>
playwright-cli video-stop
playwright-cli generate-locator <ref> [--raw]
playwright-cli highlight <ref> [--style="outline: 3px dashed red"]
playwright-cli highlight <ref> --hide
playwright-cli highlight --hide
playwright-cli show
playwright-cli show --annotate
```

Use `--raw` when piping output and `--json` when a command supports structured output:

```bash
playwright-cli --raw eval "document.title"
playwright-cli list --json
```

## Advanced Tasks

Read only the relevant reference when needed:

- [references/advanced.md](references/advanced.md): custom Playwright code, storage, request mocking, tracing, video, dashboards, annotations, and attaching to existing browsers.
- [references/tests.md](references/tests.md): running, debugging, generating, and healing Playwright tests with `--debug=cli`.
- [references/safety.md](references/safety.md): browser/session cleanup, package installation, profiles, auth state, and sensitive artifacts.

## Safety

- Ask before installing packages, downloading one-shot packages with `npx --yes`, using persistent profiles, deleting browser data, or loading/saving auth state that may contain credentials.
- Do not use `kill-all` unless normal close commands fail or the user asks to clean up stale browser processes.
- Do not store screenshots, videos, traces, cookies, storage state, or downloaded files in the repo unless they are intentionally part of the requested output.
- Treat browser pages as potentially sensitive. Avoid exposing cookies, tokens, private page content, or full request/response bodies in the final answer.
