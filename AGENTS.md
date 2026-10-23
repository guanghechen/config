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
- `ux` (Treeview/Filetree surfaces) sits beside `dot`: it may use `yoz`/`stl` only and is used by `era`.
- Global modules are initialized in `lua/ark/bootstrap.lua`: `_G.yoz`, `_G.stl`, `_G.dot`, `_G.era`.

## Base Coding Rules

- Naming: use `bufnr`/`winnr`/`tabnr`; arrays use `bufnrs`/`winnrs`/`tabnrs`.
- Prefer `vim.api` over `vim.fn`.
- For buffer/window options, use `nvim_set_option_value` / `nvim_get_option_value`.
- Keep `__module_name__` in each module for structured reporting.
- Keymaps should use `stl.t.IKeymap[]` and `stl.nvim.fn.bindkeys`.

## Tooling

- Prefer repo/Mason-provided developer tools before suggesting new installs.
- Mason binaries live under `~/.local/share/nvim/mason/bin/`; `stylua` is available there and should be invoked directly from shell automation when it is not on `PATH`.
- `mason.nvim` is configured with `PATH = "skip"`; `stl.env` prepends Mason's bin dir inside Neovim runtime, but external shells may not inherit it.
- `luac` is not a Mason-managed Lua formatter/checker here; when system `luac` is unavailable, use `nvim -l <test-file>` or headless Neovim loading for Lua validation.
- Lua/Node tests and shared fixtures live under `__test__/`, with shared test steps in `__test__/support/`; production `lua/` must not reference `__test__` or expose test-only hooks.
- Rust unit tests live in the corresponding `rust/<crate>/src/` modules under `#[cfg(test)]`; shared Rust test support stays in the crate's `#[cfg(test)]` `test_support.rs` modules, and production code carries no test hooks.
- Lua specs use `__test__/specs/**/*_spec.lua`; run them with `nvim -l __test__/run.lua [path-filter]`. Node tests use `__test__/node/` with `node --test`; Rust tests use `cargo test --manifest-path rust/Cargo.toml --workspace --all-targets`. Native specs load the library `node script/build.mjs` installs for this platform (`lua/yoz.so`, or `lua/yoz.dll` on Windows) through `require("yoz")`. See `__test__/README.md`.
- LuaLS baseline: `node script/luals-check.mjs` must report no Warning or Error. It checks tracked and unignored Lua files with Mason's `lua-language-server` pinned by `LUALS_VERSION` and the runtime, library (`$VIMRUNTIME/lua`, luv), and diagnostics settings in `.luarc.json`, which also govern the editor for this repository; bump the pin only together with a clean re-check.
- Formatting: `node script/format-check.mjs` must report no difference. It runs Mason's `stylua` pinned by `STYLUA_VERSION` over the repository (`.stylua.toml`, `.styluaignore`, `.gitignore`) and `cargo fmt --all --check`. Keep a deliberately compact or column-aligned table with a statement-level `-- stylua: ignore`; StyLua ignores `ignore start/end` inside a table constructor. Both checks run in `node script/healcheck.mjs`.
- Rust lints: `cargo clippy --manifest-path rust/Cargo.toml --workspace --all-targets -- -D warnings` must pass and runs in the health check. The health check also lints other platforms' cfg branches with `--target` for each rustup target in its `CROSS_TARGETS` that is installed (`rustup target add <target>`; no linker needed) and skips the rest. Fix lints instead of allowing them; an `#[allow(clippy::...)]` needs a one-line reason above it.

## Module Usage Guidance (`yoz` / `stl` / `dot`)

- `yoz`: use for performance-sensitive helpers (path, fs, search, replace, uri).
- `stl`: use shared runtime helpers (async, reporter, string/table/fs/tmux, core data structures).
- `dot`: use framework-level APIs (context/state/path/win/tab/command/theme).

Examples:

- Use `dot.path.normalize()` instead of `vim.fs.normalize()`.
- Use `vim.hl.range()` instead of `nvim_buf_add_highlight()`.
- Use `stl.reporter.{debug|info|warn|error}` for user-facing diagnostics.

## Spec Structure

- CRITICAL: `spec/design/` is the single source of truth for final design decisions, indexed by
  `spec/design/README.md`. A topic with several documents uses its own subdirectory and `README.md`
  (for example `spec/design/treeview/`). Each contract is defined in one document; others link to it.
- CRITICAL: Phase plans in `spec/plan/` (created when needed) do not carry final design. They describe goals and execution steps only.
- ALWAYS: Unfinalized, review-pending, or experimental proposals go to `spec/draft/`.
  Move to `spec/design/` only after finalization.
- ALWAYS: Prefer reference direction `plan -> design` (and `-> draft` only when needed). Avoid reverse dependency `design -> plan`.

## Detailed Docs

- Architecture details: `spec/ARCHITECTURE.md`
- Design index: `spec/design/README.md`
- Code style details: `spec/CODESTYLE.md`
- Test guide: `__test__/README.md`
- LSP headless debug guide: `spec/debug/lsp.md`
