# AGENT.md

This file provides guidance when working with code in this repository.

## Project Overview

This is a sophisticated, deeply-customized Neovim configuration that combines Lua and Rust for enhanced performance. Rust-native helpers are exposed through the `yoz` module, giving Lua fast search, replace, filesystem, and string utilities. The architecture implements a completely custom framework with modular design patterns.

## Architecture

### Module Dependency Order

The modules follow a strict dependency hierarchy (lower layers must not depend on higher layers):

```
yoz → stl → dot → era → ark/vendor
```

| Layer | Module   | Description                                                                   |
|:------|:---------|:------------------------------------------------------------------------------|
| L0    | `yoz`    | Rust-native library, independent Lua extension, no Neovim dependency          |
| L1    | `stl`    | Standard library, may use `yoz` and `vim` globals                             |
| L2    | `dot`    | Core framework: configuration, context, theme, commands; depends on yoz/stl   |
| L3    | `era`    | Business layer: actions, UI modules, plugin configs; depends on yoz/stl/dot   |
| L4    | `vendor` | Environment entry points: neovim/neovide/vscode                               |

### Global Variables

Three global variables are exposed via `_G` (set in `ark/bootstrap.lua`):
- `_G.yoz` → `require("yoz")` - Rust-powered helpers
- `_G.stl` → `require("stl")` - Standard library
- `_G.dot` → `require("dot")` - Core framework

### Core Module Structure

#### `lua/yoz` - Rust Native Module

Compiled Rust native module (`.so` on Unix, `.dll` on Windows; no Lua wrapper).

**Submodules:**

| Module         | Description                                                           |
|:---------------|:----------------------------------------------------------------------|
| `yoz.dict`     | Dictionary search for English word completion                          |
| `yoz.find`     | File finding (fd-like)                                                 |
| `yoz.fn`       | Utility functions (uuid, md5)                                          |
| `yoz.fs`       | File system operations (collect_files, readdir, move, get_filesize)    |
| `yoz.path`     | Path handling (normalize, join, relative, resolve, split, basename)    |
| `yoz.replace`  | Text replacement with regex support and preview                        |
| `yoz.search`   | Content search (ripgrep-like, search_in_files, search_in_lines)        |
| `yoz.string`   | String utilities (calc_linewidths, count_lines, parse_lines)           |
| `yoz.uri`      | URI handling (encode/decode, filepath conversion)                      |

Type definitions: `lua/__types__/yoz/`

#### `lua/stl/` - Standard Library Layer

Standard library with environment detection and dictionary data.

**Key Modules:**

| Module             | Description                                                          |
|:-------------------|:---------------------------------------------------------------------|
| `stl.env`          | Environment detection (OS, terminal, paths, IS_MAC/WIN/WSL/NIX)      |
| `stl.fn`           | Utility functions (boolean, identity, noop, equals_*, navigate_*, observe) |
| `stl.reporter`     | Notification system (debug/info/warn/error with structured options)  |
| `stl.fileicon`     | File icon definitions                                                 |
| `stl.filetype`     | Filetype constants and detection utilities                           |
| `stl.icon`         | Icon definitions (UI, diagnostics, LSP, DAP, Git)                    |
| `stl.json`         | JSON utilities with comment stripping                                 |
| `stl.fs`           | File system utilities (read_json, write_json, watch_file)            |

**Data Structures (`stl.c.*`):**

| Class              | Description                                                          |
|:-------------------|:---------------------------------------------------------------------|
| `Observable`       | Reactive value container with subscription support                   |
| `Subscriber`       | Observer for Observable changes                                       |
| `Subscribers`      | Collection of subscribers                                             |
| `History`          | Navigation history with capacity limit                               |
| `Frecency`         | Frequency + recency based ranking                                    |
| `Scheduler`        | Throttle/debounce task scheduling                                    |
| `Ticker`           | Counter with subscription support                                     |
| `Disposable`       | Resource cleanup abstraction                                          |
| `BatchDisposable`  | Batch disposal of multiple resources                                  |
| `BatchHandler`     | Batch operation handler with error collection                        |
| `Dirtier`          | Dirty state tracking                                                  |
| `CircularQueue`    | Fixed-size circular queue                                             |
| `CircularStack`    | Fixed-size circular stack                                             |
| `Tree`             | Generic tree structure                                                |
| `Filetree`         | File tree with lazy loading                                           |
| `Theme`            | Theme management with highlight compilation                          |
| `Proc`             | Process management                                                    |

#### `lua/dot/` - Core Framework Layer

**Context System (`dot.context.*`):**

Persistent configuration with Observable-based state management:

| Scope       | Modules                                                                          |
|:------------|:---------------------------------------------------------------------------------|
| `editor/`   | `behavior`, `theme` - Editor-wide settings                                       |
| `session/`  | `tab` - Session-level settings                                                   |
| `workspace/`| `bookmark`, `colorpicker`, `explorer`, `flight`, `frecency`, `lsp`, `module`, `option`, `plugin`, `search_buffer`, `search_file`, `select` |

**Command System (`dot.command`):**

Definition-implementation separation pattern:

```lua
-- Define command (creates vim user command)
D.new("Fbufclose", "buf: close")

-- Implement command (can be tab-type specific)
M.implement({ uuid = "Fbufclose", action = function() ... end })
M.implement({ uuid = "Fbufclose", tabtype = "terminal", action = function() ... end })

-- Execute command
dot.command.execute("Fbufclose")
```

**Core Modules:**

| Module        | Description                                                          |
|:--------------|:---------------------------------------------------------------------|
| `dot.buf`     | Buffer utilities (loadfile, resolve metadata, pick_filepath)         |
| `dot.win`     | Window utilities (is_sourcefile, pick_sourcefile, locate_symbols)    |
| `dot.tab`     | Tab utilities (resolve_type, get_bufnrs)                             |
| `dot.path`    | Path utilities (workspace, cwd, locate_* helpers)                    |
| `dot.var`     | Constants (namespaces, signs, themes, togglers, zindex)              |
| `dot.session` | Session save/restore                                                  |
| `dot.lsp`     | LSP utilities                                                         |
| `dot.notifier`| Custom notification system                                            |

**Theme System (`dot.theme.*`):**

| Component      | Description                                                                      |
|:---------------|:---------------------------------------------------------------------------------|
| `scheme/`      | 18 color schemes (catppuccin, gruvbox, nord, onehalf, rosepine, tokyonight, vsc) |
| `hlgroup/`     | Highlight groups with theme-specific overrides                                   |

**State Management (`dot.state.*`):**

| Module       | Description                                                              |
|:-------------|:-------------------------------------------------------------------------|
| `status`     | Global status (dirtiers, disposables, observables for LSP/mode messages) |
| `maximized`  | Window maximize state                                                    |
| `notepad/`   | Notepad widget state                                                     |
| `qflist`     | Quickfix list state                                                      |
| `widget`     | Active widget tracking                                                   |

#### `lua/era/` - Business Layer

**Modules (`era/m/`):**

| Module        | Description                                                    |
|:--------------|:---------------------------------------------------------------|
| `ai/`         | AI integration (config, prompt, types)                         |
| `clipboard/`  | Cross-platform clipboard (mac, win, wsl)                       |
| `colorpicker/`| Color picker UI with format conversion                         |
| `explorer/`   | File explorer (node, view, types)                              |
| `git/`        | Git integration (state, buffer, repo, types)                   |
| `lsp/`        | LSP utilities (types, symbol path finding)                     |
| `nvimbar/`    | Status/tab/window bar components                               |
| `era/m/wk/`   | Key binding manager (WhichKey)                                 |
| `picker/`     | Picker UI (finder, preview, composer)                          |
| `plugin/`     | Custom plugin loader (loader, state, view, types)              |
| `searcher/`   | Search and replace UI (finder, preview, composer)              |
| `term/`       | Terminal management                                            |
| `winsep/`     | Window separator styling                                       |

**Functions (`era/fn/`):**

| Function               | Description                                           |
|:-----------------------|:------------------------------------------------------|
| `find-buffers`         | Find open buffers                                     |
| `find-files`           | Find files in workspace                               |
| `find-diagnostics`     | Find diagnostics                                      |
| `find-lsp-symbols`     | Find LSP symbols                                      |
| `search-in-files`      | Search and replace in files                           |
| `search-in-buffer`     | Search in current buffer                              |
| `pick_win`             | Window picker                                         |
| `rename`               | File/symbol rename                                    |
| `run_code`             | Code runner                                           |

**Views (`era/view/`):**

| View         | Description                                                     |
|:-------------|:----------------------------------------------------------------|
| `act`        | Action board                                                    |
| `keysheet`   | Keymap reference                                                |
| `plainfile`  | Plain file renderer                                             |
| `printer`    | Generic text printer                                            |
| `setting`    | Settings UI                                                     |
| `textarea`   | Text area component                                             |
| `tree`       | Tree view renderer                                              |

**Plugin Configs (`era/plugin/`):**

Individual plugin configurations: blink-cmp, flash, mini-*, nvim-dap, nvim-treesitter, etc.

#### `lua/ark/` - Bootstrap Layer

Loaded before stl/dot, sets up global variables, patches, and workspace.

| File             | Description                                           |
|:-----------------|:------------------------------------------------------|
| `bootstrap.lua`  | Main bootstrap (sets _G.yoz, _G.stl, _G.dot)          |
| `autocmd.lua`    | Early autocommands                                     |
| `keymap.lua`     | Early keymaps                                          |
| `option.lua`     | Early options                                          |

**Vendor Entry Points (`ark/vendor/`):**

| Vendor      | Description                                                          |
|:------------|:---------------------------------------------------------------------|
| `neovim/`   | Standard Neovim setup                                                 |
| `neovide/`  | Neovide GUI setup                                                     |
| `vscode/`   | VSCode extension setup                                                |

### Module Access Patterns

**Lazy Loading via Metatable:**

```lua
-- Access triggers require() on first use
dot.buf.loadfile(filepath)     -- requires "dot.buf"
stl.c.Observable.new({...})    -- requires "stl.c.observable"
era.m.picker.open({...})       -- requires "era.m.picker"
```

**Common Patterns:**

```lua
-- Observable state
local theme = dot.context.theme.theme:snapshot()  -- Get current value
dot.context.theme.theme:next("gruvbox-dark")      -- Set new value
dot.context.theme.theme:subscribe(subscriber)     -- React to changes

-- Command execution
dot.command.definitions.buf.close:execute()

-- Path utilities (use dot.path, not vim.fs)
local normalized = dot.path.normalize(filepath)
local relative = dot.path.relative(dot.path.cwd(), filepath)

-- Reporter (use stl.reporter, not vim.notify)
stl.reporter.error({
  from = __module_name__,
  subject = "Operation",
  message = "Error message",
  details = { key = "value" },
})
```

### Plugin Loader

Custom lightweight plugin loader (`era/m/plugin/loader.lua`):

- Supports lazy loading via `event`, `cmd`, `ft`, `keys`
- Installs package loader for automatic plugin loading on require
- Fires `User PluginLoad` autocmd when plugin loads
- Fires `User VeryLazy` after UI enters

```lua
---@type era.m.plugin.IPluginSpec
{
  name = "plugin-name",
  main = "plugin",           -- Optional: main module name
  lazy = true,               -- Optional: enable lazy loading
  event = "VeryLazy",        -- Optional: load on event
  cmd = { "Cmd1", "Cmd2" },  -- Optional: load on command
  ft = { "lua", "rust" },    -- Optional: load on filetype
  keys = { { lhs = "<leader>x", rhs = function() end } },
  dependencies = { "dep1" }, -- Optional: load dependencies first
  config = function(spec, opts) end,
}
```

### Rust-Lua Bridge

| Component        | Location                                              |
|:-----------------|:------------------------------------------------------|
| Compiled Library | `lua/yoz.so` (Unix) / `lua/yoz.dll` (Windows)         |
| Source Code      | `rust/yoz/src/`                                       |
| Build Command    | `./rust/build.sh --force`                             |

## Code Conventions

### Neovim Version
- This configuration only supports the latest Neovim version; no backward compatibility code is needed

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
vim.api.nvim_win_get_cursor(...)   -- not vim.fn.getcurpos()

-- Prefer explicit variables over magic 0
local tabnr = vim.api.nvim_get_current_tabpage() ---@type integer
local winnrs = vim.api.nvim_tabpage_list_wins(tabnr) ---@type integer[]

-- Use vim.uv directly (not vim.uv or vim.loop)
vim.uv.hrtime()

-- Use vim.bo/vim.wo instead of deprecated APIs
vim.bo[bufnr].filetype     -- not nvim_buf_get_option
vim.wo[winnr].number       -- not nvim_win_get_option

-- Use dot.path.normalize instead of vim.fs.normalize
dot.path.normalize(filepath)

-- Use vim.hl.range instead of deprecated nvim_buf_add_highlight
vim.hl.range(bufnr, ns, hlgroup, start_pos, end_pos)
```

### Type Annotations

**Column Alignment (column 40):**

```lua
---@param name                        string
---@param callback                    fun(result: boolean): nil
---@return nil
```

**Type on Same Line (single-line targets):**

```lua
local bufnr = vim.api.nvim_get_current_buf() ---@type integer
local name = "example" ---@type string
```

**Type Above (multi-line targets):**

```lua
---@type IConfig
local config = create_config({
  key = "value",
})
```

**Union Types:**

```lua
---@alias era.git.StageState
---| "staged"
---| "unstaged"
---| "mixed"
---| nil
```

**Class Fields (visibility required, column 40 alignment):**

```lua
---@class foo.bar.MyClass
---@field public name                 string
---@field public callback             fun(): nil
---@field protected _internal         integer
```

**Adjacent Type Definitions (blank line between):**

```lua
---@alias foo.TypeA string

---@alias foo.TypeB number
```

### Protected Methods

- Use `__method_name__` naming convention
- Place at end of class, after 100-char separator
- Order alphabetically

```lua
---@class foo.Example
local M = {}

function M.public_method() end

----------------------------------------------------------------------------------------------------

function M.__protected_alpha__() end

function M.__protected_beta__() end
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
local __module_name__ = "dot.buf" ---@type string
```

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

## Supporting Directories

| Directory      | Description                                           |
|:---------------|:------------------------------------------------------|
| `ftplugin/`    | Filetype-specific settings                            |
| `lsp/`         | 21 language server configurations                     |
| `queries/`     | TreeSitter queries                                    |
| `rust/yoz/`    | Rust source code                                      |
| `doc/`         | Documentation and issue tracking                      |
| `lua/__types__/`| Type definitions for LSP                             |

## Key Features

- Rust-powered search, replace, and file operations for performance
- Multi-environment support: Neovim, Neovide, VSCode
- Automatic session management for git repositories
- Custom UI components: status line, tab line, window line, picker, searcher
- AI integration module with multiple providers
- Custom file explorer widget
- Notepad widget for scratch notes
- Comprehensive git integration (blame, hunk navigation, staging)
- Color picker with multiple format support
- Custom lightweight plugin loader with lazy loading
