# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

**Important**: This is a personal-use config. Only support latest Neovim version—no backward compatibility needed. No configurability required—hardcode values directly, avoid unnecessary abstraction.

## Project Overview

This is a deeply-customized Neovim configuration combining Lua and Rust. Rust-native helpers are exposed through the `yoz` module for fast search, replace, filesystem, and string utilities.

## Architecture (Summary)

```
yoz → stl → dot → era → ark/vendor
```

| Layer | Module   | Description                                                  |
|:------|:---------|:-------------------------------------------------------------|
| L0    | `yoz`    | Rust-native library, no Neovim dependency                    |
| L1    | `stl`    | Standard library, may use `yoz` and `vim` globals            |
| L2    | `dot`    | Core framework: configuration, context, theme, commands      |
| L3    | `era`    | Business layer: actions, UI modules, plugin configs          |
| L4    | `vendor` | Environment entry points: neovim/neovide/vscode              |

**Global Variables** (set in `ark/bootstrap.lua`): `_G.yoz`, `_G.stl`, `_G.dot`, `_G.era`

For module details, data flow, or async patterns, refer to `spec/ARCHITECTURE.md`.

## Code Style (Summary)

- Naming: `bufnr`/`winnr`/`tabnr`, arrays use `bufnrs`/`winnrs`/`tabnrs`
- Prefer `vim.api` over `vim.fn`
- Use `nvim_set_option_value`/`nvim_get_option_value` for buffer/window options
- Type annotations align to column 40
- Optional params/fields use `?` prefix; return types use `|nil` suffix
- Define `__module_name__` in each module for error reporting
- Keymap: use `stl.t.IKeymap[]` + `stl.nvim.fn.bindkeys`

**Don'ts:**

- `vim.fn.bufnr()` / `vim.fn.winnr()` → use `vim.api` equivalents
- `vim.bo` / `vim.wo` → use `nvim_set_option_value` / `nvim_get_option_value`
- `vim.fs.normalize()` → use `dot.path.normalize()`
- `nvim_buf_add_highlight()` → use `vim.hl.range()`
- Magic `0` for current buf/win/tab → use explicit `nvim_get_current_*()` variables

For detailed examples or style fixes, refer to `spec/CODESTYLE.md`.

## Debug

- `:messages` is not available; use `:Fuxcopynotifications` to copy notification history to clipboard
- To collect LSP diagnostics in headless mode, follow the instructions in `spec/debug/lsp.md`
