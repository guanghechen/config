---
name: windows-path
description: Preview, reorder, deduplicate, finalize, or safely update Windows System/User PATH environment variables. Use when the user asks to inspect, clean up, sort, reorder, deduplicate, or write Windows PATH entries.
argument-hint: "[preview | finalize | apply]"
---

# Windows PATH

Inspect and reorder Windows `Path` environment variables safely. The skill is **preview-first**: it never writes PATH unless the user explicitly asks, and it refuses writes that could silently corrupt PATH.

## Modes

| Mode           | Trigger                                            | Writes PATH |
|----------------|----------------------------------------------------|-------------|
| `preview-only` | default                                            | no          |
| `finalize`     | user explicitly says `submit` / `finalize`         | no          |
| `apply`        | user explicitly says `update` / `apply` / `write`  | yes         |

Stay in `preview-only` until the user explicitly escalates. Keep every response focused on the PATH workflow.

## 1. Read PATH

First determine whether the host is Windows. On non-Windows hosts, never read, infer, or write Windows PATH from local environment values — request manual fallback or ask the user to run from Windows.

On Windows hosts, read both scopes from the registry **without expanding variables**, so entries like `%SystemRoot%\system32` are preserved verbatim:

- System: `reg query "HKLM\SYSTEM\CurrentControlSet\Control\Session Manager\Environment" /v Path`
- User: `reg query "HKCU\Environment" /v Path`

Record each scope's registry type from the `reg query` output (`REG_SZ` or `REG_EXPAND_SZ`) — it is needed to write back correctly and to detect expandable entries. Prefer `powershell -NoProfile` for any PowerShell step; treat profile noise on stderr as non-fatal if values are returned.

If PATH cannot be read, request manual fallback for the failed scope(s) only:

```text
System PATH:
<entry 1>
<entry 2>

User PATH:
<entry 1>
<entry 2>
```

Parse entries by `;` or line breaks (`\r\n`, `\n`, `\r`); trim and drop empty entries. An empty scope is valid and shown as `(empty)`.

## 2. Process (per scope)

Treat `System PATH` and `User PATH` as fully independent; never move entries across scopes.

1. **Normalize**: remove trailing `\` from non-root paths; keep root paths like `C:\` intact.
2. **Deduplicate**: compare case-insensitively, keep the first occurrence, drop later duplicates. In `Original`, keep removed items in place as `~~<path>~~ (removed)`.
3. **Sort**: group, then sort alphabetically within each group (case-insensitive):
   1. prefix `C:\app` or `C:\app\`
   2. contains `\Microsoft\WinGet\` or `\WinGet\`
   3. others

## 3. Output

### Preview Mode

Print exactly one source line, then the sections in this exact order:

- Source line: `Source: Windows System PATH + User PATH` or `Source: Manual fallback input`
- `## System Env` → `### Original` → `### Ordered Preview`
- `## User Env` → `### Original` → `### Ordered Preview`
- `## Next Step`

Rules:

- `### Original`: preserve parsed order; show removed items as `~~<path>~~ (removed)`.
- `### Ordered Preview`: normalized, deduplicated, sorted; `(empty)` if none.
- `## Next Step` must be exactly: `Waiting for your instruction: adjust order or submit final order.`

### Finalize Mode

Output exactly these sections, in order:

1. `### Final System PATH`
2. `### Final User PATH`
3. `### Removed Entries`

Rules:

- Final PATH values are single-line strings joined by `;`.
- Empty scope output is `(empty)`.
- `Removed Entries` grouped by `System PATH` and `User PATH`; `(none)` if none.
- Do not include `Next Step`.

### Apply Mode

Run the pre-write gates in section 4 first. Then output exactly these sections, in order:

1. `### Apply Result` — per scope `success`, `failed`, or `skipped`; for `failed`, a concise non-sensitive reason.
2. `### Post-Write Verification` — per scope `verified` or `mismatch`.
3. `### Next Step`

Never claim success without read-back verification.

## 4. Write PATH (apply mode only)

Write only the scope(s) the user explicitly requested. Before writing any scope, pass all of these gates — fail the gate ⇒ skip that scope and report why:

1. **Confirm value**: confirm the target scope(s) and final PATH string(s) unless already explicitly finalized.
2. **Expandable-variable guard**: if the scope's entries contain `%...%` (e.g. `%SystemRoot%`), or its registry type is `REG_EXPAND_SZ`, do NOT write via the .NET API below — it expands variables and rewrites the value as `REG_SZ`, permanently freezing `%SystemRoot%\system32` into `C:\Windows\system32`. Skip the scope and tell the user to edit it manually (or escalate to a registry-preserving write only on explicit request).
3. **Privilege check (System only)**: writing `Machine` scope needs an elevated session. Verify with `([Security.Principal.WindowsPrincipal][Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole([Security.Principal.WindowsBuiltinRole]::Administrator)`. If not elevated, skip the System scope and tell the user to rerun as Administrator. User scope needs no elevation.

Write command — pass the final value through a single-quoted PowerShell variable; never inline raw entries. In a single-quoted string only `'` needs escaping (double it to `''`); backtick, `&`, `$`, spaces are literal and safe:

```powershell
$p = '<final PATH, every literal '' doubled>'
[Environment]::SetEnvironmentVariable('Path', $p, '<Machine|User>')
```

- Example: `C:\Users\O'Brien\bin` must appear in the value as `C:\Users\O''Brien\bin`.
- After each write, read the scope back and compare against the intended value; report `verified` or `mismatch`.

## Safety

- Default to `preview-only`; never write in preview or finalize mode.
- On non-Windows hosts, use manual fallback only — never touch local environment values.
- Refuse to write a scope that fails any section-4 gate; a skipped scope is safer than a corrupted PATH.

## Validation Checklist

- PATH read unexpanded from the registry; registry type recorded per scope.
- Preview output follows the exact source-line + section order; `System Env` / `User Env` each appear once.
- `Original` keeps order and removed markers; `Ordered Preview` is normalized, deduplicated, sorted.
- Finalize output has exactly 3 sections; Apply output has exactly 3 sections.
- Apply passed all gates (value confirmed, no expandable-variable corruption, System scope elevated) and includes read-back verification.
