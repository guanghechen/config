# Playwright CLI Safety

## Package Installation

Do not install or download packages without user approval. This includes global installs and one-shot `npx --yes` downloads.

The maintained package is `@playwright/cli`. The older `playwright-cli` npm package is deprecated even though the executable name remains `playwright-cli`.

## Sessions And Cleanup

Use semantic session names for multi-step work:

```bash
playwright-cli -s=checkout open http://localhost:3000
```

Close sessions after work:

```bash
playwright-cli -s=checkout close
```

Use `close-all` only when all active sessions belong to the current task. Use `delete-data` only when the user asks to remove session data or cleanup requires it. Use `kill-all` only when normal close fails or the user asks to clean up stale browser processes.

## Persistent Data

Avoid persistent profiles unless explicitly needed.

```bash
playwright-cli open --persistent
playwright-cli open --profile=/path/to/profile
```

Do not save, print, or commit auth state, cookies, localStorage, sessionStorage, traces, videos, screenshots, PDFs, or downloaded files unless they are intentionally part of the requested output.

## Sensitive Page Content

Browser automation can expose private pages, tokens, cookies, request bodies, and screenshots. Summarize sensitive evidence instead of pasting raw values. Mask tokens and credentials in final answers.

## Repo Hygiene

Keep generated artifacts out of the repo by default. Prefer temporary paths or `.playwright-cli/` outputs only when the task needs them. Clean up stale artifacts when they are no longer useful.
