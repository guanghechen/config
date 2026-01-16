# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Project Overview

This is a deeply-customized Neovim configuration combining Lua and Rust. Rust-native helpers are exposed through the `yoz` module for fast search, replace, filesystem, and string utilities.

For detailed architecture information, see `ARCHITECTURE.md`.

## Module Dependency Order

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

**Global Variables** (set in `ark/bootstrap.lua`):
- `_G.yoz`, `_G.stl`, `_G.dot`, `_G.era`

## Code Conventions

### Neovim Version

- Only supports the latest Neovim version; no backward compatibility code needed

### Variable Naming

| Convention | Example                                           |
|:-----------|:--------------------------------------------------|
| Buffer nr  | `bufnr` (not `buf`)                               |
| Window nr  | `winnr` (not `win`)                               |
| Tab nr     | `tabnr` (not `tab`)                               |
| Arrays     | `bufnrs`, `winnrs`, `tabnrs` (not `bufs`, `wins`) |

### API Preferences

```lua
-- Prefer vim.api over vim.fn
vim.api.nvim_get_current_buf()     -- not vim.fn.bufnr()
vim.api.nvim_get_current_win()     -- not vim.fn.winnr()
vim.api.nvim_buf_get_lines(...)    -- not vim.fn.getline()

-- Prefer explicit variables over magic 0
local tabnr = vim.api.nvim_get_current_tabpage() ---@type integer
local winnrs = vim.api.nvim_tabpage_list_wins(tabnr) ---@type integer[]

-- Use vim.uv directly
vim.uv.hrtime()

-- Buffer/window options: use nvim_set_option_value / nvim_get_option_value
vim.api.nvim_set_option_value("filetype", "lua", { buf = bufnr })
vim.api.nvim_get_option_value("modifiable", { buf = bufnr })
vim.api.nvim_set_option_value("number", false, { win = winnr, scope = "local" })

-- Use dot.path.normalize instead of vim.fs.normalize
dot.path.normalize(filepath)

-- Use vim.hl.range instead of deprecated nvim_buf_add_highlight
vim.hl.range(bufnr, ns, hlgroup, start_pos, end_pos)
```

### Type Annotations

**Column Alignment (column 40):**

```lua
---@param name                          string
---@param callback                      fun(result: boolean): nil
---@return nil
```

**Type on Same Line (single-line targets):**

```lua
local bufnr = vim.api.nvim_get_current_buf() ---@type integer
```

**Type Above (multi-line targets):**

```lua
---@type IConfig
local config = create_config({
  key = "value",
})
```

**Class Fields (visibility required, column 40 alignment):**

```lua
---@class foo.bar.MyClass
---@field public name                   string
---@field public callback               fun(): nil
---@field protected _internal           integer
```

### Error Reporting

```lua
stl.reporter.error({
  from = __module_name__,
  subject = "Operation Name",
  message = "Error message here",
  details = { key = "value" },  -- Optional, displayed as JSON
})
-- Same interface for stl.reporter.{error|warn|info|debug}
```

### Module Name Pattern

Each module should define `__module_name__` for error reporting:

```lua
---@diagnostic disable-next-line: unused-local
local __module_name__ = "era.m.colorpicker.mode" ---@type string
```

### Protected Methods

- Use `__method_name__` naming convention
- Place at end of class, after 100-char separator
- Order alphabetically

### Keymap Ordering

1. Mouse keys (`<LeftMouse>`, `<2-LeftMouse>`, `<RightMouse>`)
2. `<M-*>` (Meta/Alt)
3. `<D-*>` (Command/Super)
4. `<C-a>*` (Ctrl-a prefix)
5. `<C-*>` (other Ctrl)
6. Special keys (`<CR>`, `<Tab>`, `<BS>`, `<Esc>`)
7. Uppercase letters (A-Z)
8. Lowercase letters (a-z)
9. Symbols and numbers

Within each category, sort alphabetically.

### Rust Integration

When modifying `rust/yoz/src/`:
- Follow existing mlua patterns for serialization/deserialization
- Keep Lua-facing APIs synchronized with Lua call sites
- Prefix Rust unit test function names with `t_` (e.g., `fn t_parses_config()`)

## Debug

- `:messages` is not available; use `:Fuxcopynotifications` to copy notification history to clipboard
