# AGENTS.md

This file provides guidance to autonomous agents (Codex, GPT, or similar) when working with code in this repository.

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

## Core Modules Quick Reference

### `yoz` - Rust Native Module

| Module         | Key Functions                                                        |
|:---------------|:---------------------------------------------------------------------|
| `yoz.path`     | `normalize`, `join`, `relative`, `resolve`, `split`, `basename`, `is_exist` |
| `yoz.fs`       | `collect_files`, `readdir`, `move`, `get_filesize`                   |
| `yoz.search`   | `search_in_files`, `search_in_lines`, `search_in_text`               |
| `yoz.replace`  | `replace_file`, `replace_file_preview`, `replace_text_preview`       |
| `yoz.string`   | `calc_linewidths`, `count_lines`, `parse_lines`, `get_locations`     |
| `yoz.uri`      | `from_filepath`, `to_filepath`, `encode`, `decode`                   |
| `yoz.fn`       | `uuid`, `md5`                                                         |
| `yoz.dict`     | Dictionary search for completion                                      |
| `yoz.find`     | File finding (fd-like)                                                |

### `stl` - Standard Library

| Module          | Purpose                                                              |
|:----------------|:---------------------------------------------------------------------|
| `stl.env`       | Environment detection (IS_MAC/WIN/WSL/NIX, paths, terminals)         |
| `stl.fn`        | Utilities (identity, noop, equals_*, navigate_*, observe)            |
| `stl.reporter`  | Notifications (debug/info/warn/error)                                |
| `stl.fs`        | File utilities (read_json, write_json, watch_file)                   |
| `stl.c.*`       | Data structures (Observable, History, Scheduler, Disposable, etc.)   |

### `dot` - Core Framework

| Module          | Purpose                                                              |
|:----------------|:---------------------------------------------------------------------|
| `dot.buf`       | Buffer utilities (loadfile, resolve, pick_filepath)                  |
| `dot.win`       | Window utilities (is_sourcefile, pick_sourcefile, locate_symbols)    |
| `dot.tab`       | Tab utilities (resolve_type, get_bufnrs)                             |
| `dot.path`      | Path utilities (workspace, cwd, locate_* helpers)                    |
| `dot.command`   | Command definition and execution                                      |
| `dot.context.*` | Persistent configuration (editor/session/workspace scopes)           |
| `dot.state.*`   | Runtime state management                                              |
| `dot.theme.*`   | Theme system (18 schemes, highlight groups)                          |
| `dot.var`       | Constants (namespaces, signs, themes, zindex)                        |

### `era` - Business Layer

| Module            | Purpose                                                            |
|:------------------|:-------------------------------------------------------------------|
| `era/m/picker/`   | Fuzzy picker UI                                                     |
| `era/m/searcher/` | Search and replace UI                                               |
| `era/m/explorer/` | File explorer                                                       |
| `era/m/nvimbar/`  | Status/tab/window bar                                               |
| `era/m/wk/`       | Key binding manager (WhichKey)                                      |
| `era/m/git/`      | Git integration                                                     |
| `era/m/plugin/`   | Custom plugin loader                                                |
| `era/fn/*`        | Action functions (find-files, search-in-files, etc.)                |
| `era/view/*`      | View renderers (tree, plainfile, printer, etc.)                     |
| `era/plugin/*`    | Individual plugin configurations                                    |

## Code Conventions

### Variable Naming

```lua
local bufnr = vim.api.nvim_get_current_buf() ---@type integer
local winnr = vim.api.nvim_get_current_win() ---@type integer
local tabnr = vim.api.nvim_get_current_tabpage() ---@type integer
local winnrs = vim.api.nvim_tabpage_list_wins(tabnr) ---@type integer[]
```

### API Preferences

```lua
-- Use vim.api over vim.fn when equivalent
vim.api.nvim_get_current_buf()     -- not vim.fn.bufnr()
vim.api.nvim_buf_get_lines(...)    -- not vim.fn.getline()

-- Use vim.bo/vim.wo (not deprecated set_option/get_option)
vim.bo[bufnr].filetype
vim.wo[winnr].number

-- Use vim.uv directly
vim.uv.hrtime()

-- Use project utilities
dot.path.normalize(filepath)       -- not vim.fs.normalize
stl.reporter.error({...})          -- not vim.notify
```

### Type Annotations

```lua
-- Column 40 alignment for parameters
---@param name                        string
---@param callback                    fun(result: boolean): nil
---@return nil

-- Same-line for single-line declarations
local bufnr = vim.api.nvim_get_current_buf() ---@type integer

-- Above for multi-line targets
---@type IConfig
local config = {
  key = "value",
}

-- Class fields require visibility modifier
---@class foo.MyClass
---@field public name                 string
---@field protected _internal         integer
```

### Protected Methods

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
local __module_name__ = "my.module" ---@type string

stl.reporter.error({
  from = __module_name__,
  subject = "Operation Name",
  message = "Error message",
  details = { key = "value" },  -- Optional JSON
})
```

## Common Patterns

### Observable State

```lua
-- Get current value
local theme = dot.context.theme.theme:snapshot()

-- Set new value
dot.context.theme.theme:next("gruvbox-dark")

-- Subscribe to changes
local subscriber = stl.c.Subscriber.new({
  on_next = function(value, prev_value)
    -- Handle change
  end,
})
dot.context.theme.theme:subscribe(subscriber)
```

### Command Execution

```lua
-- Execute by uuid
dot.command.execute("Fbufclose")

-- Execute via definition
dot.command.definitions.buf.close:execute()
```

### Plugin Spec

```lua
---@type era.m.plugin.IPluginSpec
{
  name = "plugin-name",
  lazy = true,
  event = "VeryLazy",
  cmd = { "Cmd1" },
  ft = { "lua" },
  keys = { { lhs = "<leader>x", rhs = function() end } },
  dependencies = { "dep1" },
  config = function(spec, opts) end,
}
```

## Directory Structure

```
lua/
├── yoz.so              # Rust compiled module
├── __types__/          # LuaLS type definitions
├── ark/                # Bootstrap layer
│   ├── bootstrap.lua   # Sets _G.yoz, _G.stl, _G.dot
│   └── vendor/         # Environment entry points (neovim/neovide/vscode)
├── stl/                # Standard library
│   ├── c/              # Data structure classes
│   ├── env.lua         # Environment detection
│   ├── fn.lua          # Utility functions
│   └── reporter.lua    # Notification system
├── dot/                # Core framework
│   ├── buf.lua         # Buffer utilities
│   ├── win.lua         # Window utilities
│   ├── path.lua        # Path utilities
│   ├── command.lua     # Command system
│   ├── context/        # Persistent configuration
│   ├── state/          # Runtime state
│   └── theme/          # Theme system
└── era/                # Business layer
    ├── m/              # UI modules (picker, searcher, explorer, etc.)
    ├── fn/             # Action functions
    ├── view/           # View renderers
    └── plugin/         # Plugin configurations

rust/yoz/               # Rust source code
lsp/                    # 21 LSP server configurations
ftplugin/               # Filetype-specific settings
queries/                # TreeSitter queries
doc/                    # Documentation
```

## Build Commands

```bash
# Build Rust module
./rust/build.sh --force

# Format Lua (use repo .stylua.toml)
stylua lua/
```

## Key Constraints

1. **Dependency Order**: Lower layers must not depend on higher layers
2. **No Backward Compatibility**: Only latest Neovim version supported
3. **English in Code**: Avoid Chinese characters except in dict values
4. **Type Annotations Required**: All public APIs should have types
5. **Use Project Utilities**: Prefer dot.path, stl.reporter over vim.fs, vim.notify
