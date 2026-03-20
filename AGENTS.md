# AGENTS.md

This file defines the baseline guidance for contributors and coding agents.

## Principles

- Personal config only: target latest Neovim; no backward compatibility work.
- Prefer direct, practical implementations; avoid unnecessary abstractions and optional config layers.
- Keep changes scoped to the task; do not perform unrelated refactors.

## Dependency Boundaries

Layer order must remain one-directional:

```text
yoz -> stl -> dot -> era -> ark/vendor
```

- Lower layers must not depend on higher layers.
- Global modules are initialized in `ark/bootstrap.lua`: `_G.yoz`, `_G.stl`, `_G.dot`, `_G.era`.

## Base Coding Rules

- Naming: use `bufnr`/`winnr`/`tabnr`; arrays use `bufnrs`/`winnrs`/`tabnrs`.
- Prefer `vim.api` over `vim.fn`.
- For buffer/window options, use `nvim_set_option_value` / `nvim_get_option_value`.
- Keep `__module_name__` in each module for structured reporting.
- Keymaps should use `stl.t.IKeymap[]` and `stl.nvim.fn.bindkeys`.

## Module Usage Guidance (`yoz` / `stl` / `dot`)

- `yoz`: use for performance-sensitive helpers (path, fs, search, replace, uri).
- `stl`: use shared runtime helpers (async, reporter, string/table/fs/tmux, core data structures).
- `dot`: use framework-level APIs (context/state/path/win/tab/command/theme).

Examples:

- Use `dot.path.normalize()` instead of `vim.fs.normalize()`.
- Use `vim.hl.range()` instead of `nvim_buf_add_highlight()`.
- Use `stl.reporter.{debug|info|warn|error}` for user-facing diagnostics.

## Spec Structure

- CRITICAL: `spec/design/` is the single source of truth for final design decisions. Stable design must live in `design/`.
- CRITICAL: `spec/roadmap/` and `spec/plan/` do not carry final design. They describe phase goals and execution steps only.
- ALWAYS: Unfinalized, review-pending, or experimental proposals go to `spec/draft/`. Move to `spec/design/` only after finalization.
- ALWAYS: Prefer reference direction `roadmap/plan -> design` (and `-> draft` only when needed). Avoid reverse dependency `design -> roadmap/plan`.

## Detailed Docs

- Architecture details: `spec/ARCHITECTURE.md`
- Code style details: `spec/CODESTYLE.md`
- LSP headless debug guide: `spec/debug/lsp.md`
