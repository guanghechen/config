---
name: windows-path
description: Preview, reorder, deduplicate, finalize, or safely update Windows System/User PATH environment variables. Use when the user asks to inspect, clean up, sort, reorder, deduplicate, or write Windows PATH entries.
---

# Windows PATH

Safely inspect and reorder Windows `Path` environment variables. Default to preview-only behavior and never write PATH unless the user explicitly asks.

## Modes

- `preview-only` is the default.
- `finalize` only when the user explicitly asks to `submit` or `finalize` the final order.
- `apply` only when the user explicitly asks to `update`, `apply`, or `write` PATH.

## Input

Normal flow does not accept free-form PATH input. First determine whether the current host is Windows. On non-Windows hosts, do not read or interpret local PATH values as Windows PATH; request manual fallback or ask the user to run from Windows.

On Windows hosts, read both scopes:

- System PATH: `[Environment]::GetEnvironmentVariable('Path','Machine')`
- User PATH: `[Environment]::GetEnvironmentVariable('Path','User')`

Use `powershell -NoProfile` when available. Treat profile noise on stderr as non-fatal if PATH values are returned.

If the current environment cannot read Windows PATH values, request manual fallback for the failed scope(s) only:

```text
System PATH:
<entry 1>
<entry 2>

User PATH:
<entry 1>
<entry 2>
```

Parse entries by `;` or line breaks (`\r\n`, `\n`, `\r`), then trim and remove empty entries. Empty scope values are valid and must be shown as `(empty)`.

## Processing

### Scope Boundary

- Treat `System PATH` and `User PATH` as fully independent.
- Never move entries across scopes.

### Normalization

- Remove trailing `\` from non-root paths.
- Keep root paths valid, for example `C:\`.

### Deduplication

- Deduplicate per scope after normalization.
- Compare case-insensitively.
- Keep the first occurrence and remove later duplicates.
- In `Original`, keep removed items in place as `~~<path>~~ (removed)`.

### Sorting

Group first, then sort alphabetically within each group, case-insensitively:

1. Prefix `C:\app` or `C:\app\`
2. Contains `\Microsoft\WinGet\` or `\WinGet\`
3. Others

## Output

### Preview Mode

Print exactly one source line before sections:

- `Source: Windows System PATH + User PATH`
- or `Source: Manual fallback input`

Then use this exact section order:

1. `## System Env`
2. `### Original`
3. `### Ordered Preview`
4. `## User Env`
5. `### Original`
6. `### Ordered Preview`
7. `## Next Step`

Rules:

- `### Original`: preserve parsed order and show removed items as `~~<path>~~ (removed)`.
- `### Ordered Preview`: show normalized, deduplicated, sorted result; if empty, show `(empty)`.
- `## Next Step` must be exactly: `Waiting for your instruction: adjust order or submit final order.`

### Finalize Mode

Output exactly these sections:

1. `### Final System PATH`
2. `### Final User PATH`
3. `### Removed Entries`

Rules:

- Final PATH values must be single-line strings joined by `;`.
- Empty scope output is `(empty)`.
- `Removed Entries` must be grouped by `System PATH` and `User PATH`; if none, output `(none)`.
- Do not include `Next Step`.

### Apply Mode

Output exactly these sections:

1. `### Apply Result`
2. `### Post-Write Verification`
3. `### Next Step`

Rules:

- Write only the scope(s) explicitly requested by the user.
- Before writing, confirm the final target scope(s) and final PATH string(s) if they have not already been explicitly finalized.
- Preferred write commands:
  - System PATH: `[Environment]::SetEnvironmentVariable('Path', <final_system_path>, 'Machine')`
  - User PATH: `[Environment]::SetEnvironmentVariable('Path', <final_user_path>, 'User')`
- `Apply Result`: report each scope as `success`, `failed`, or `skipped`.
- For `failed`, provide a concise non-sensitive reason.
- Read back each attempted scope and compare with the intended value.
- `Post-Write Verification`: report `verified` or `mismatch`.
- Never claim write success without read-back verification.

## Safety

- Stay in preview-only unless the user explicitly asks for `finalize` or `apply` behavior.
- Never write PATH in preview or finalize mode.
- On non-Windows hosts, do not read, infer, or write Windows PATH from local environment values; use manual fallback or ask the user to run from Windows.
- Keep responses strictly focused on PATH ordering/update workflow.

## Validation Checklist

- Preview output follows the exact 1-7 section order.
- `System Env` and `User Env` each appear once.
- `Original` keeps order and removed markers.
- `Ordered Preview` is normalized, deduplicated, and sorted.
- Finalize output has exactly 3 required sections.
- Apply output has exactly 3 required sections and includes read-back verification.
