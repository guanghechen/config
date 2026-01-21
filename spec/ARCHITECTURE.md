# ARCHITECTURE.md

This document provides detailed architecture information for this Neovim configuration.

## Module Dependency Order

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

Four global variables are exposed via `_G` (set in `ark/bootstrap.lua`):
- `_G.yoz` → `require("yoz")` - Rust-powered helpers
- `_G.stl` → `require("stl")` - Standard library
- `_G.dot` → `require("dot")` - Core framework
- `_G.era` → `require("era")` - Business layer

## Core Module Structure

### `lua/yoz` - Rust Native Module

Compiled Rust native module (`.so` on Unix, `.dll` on Windows; no Lua wrapper).

**Submodules:**

| Module         | Description                                                           |
|:---------------|:----------------------------------------------------------------------|
| `yoz.dict`     | Dictionary search for English word completion                         |
| `yoz.find`     | File finding (fd-like)                                                |
| `yoz.fn`       | Utility functions (uuid, md5)                                         |
| `yoz.fs`       | File system operations (collect_files, readdir, move, get_filesize)   |
| `yoz.path`     | Path handling (normalize, join, relative, resolve, split, basename)   |
| `yoz.replace`  | Text replacement with regex support and preview                       |
| `yoz.search`   | Content search (ripgrep-like, search_in_files, search_in_lines)       |
| `yoz.string`   | String utilities (calc_linewidths, count_lines, parse_lines)          |
| `yoz.uri`      | URI handling (encode/decode, filepath conversion)                     |

Type definitions: `lua/__types__/yoz/`

### `lua/stl/` - Standard Library Layer

Standard library with environment detection and dictionary data.

**Key Modules:**

| Module         | Description                                                      |
|:---------------|:-----------------------------------------------------------------|
| `stl.anim`     | Animation utilities                                              |
| `stl.async`    | Coroutine-based async/await utilities                            |
| `stl.box`      | Box drawing utilities                                            |
| `stl.debug`    | Debug utilities                                                  |
| `stl.env`      | Environment detection (OS, terminal, paths, IS_MAC/WIN/WSL/NIX)  |
| `stl.fileicon` | File icon definitions                                            |
| `stl.filetype` | Filetype constants and detection utilities                       |
| `stl.fn`       | Utility functions (boolean, identity, noop, equals_*, observe)   |
| `stl.fs`       | File system utilities (read_json, write_json, watch_file)        |
| `stl.hot`      | Hot reload utilities                                             |
| `stl.icon`     | Icon definitions (UI, diagnostics, LSP, DAP, Git)                |
| `stl.json`     | JSON utilities with comment stripping                            |
| `stl.reporter` | Notification system (debug/info/warn/error with structured opts) |
| `stl.shell`    | Shell command execution utilities                                |
| `stl.stdout`   | Stdout utilities                                                 |
| `stl.string`   | String manipulation utilities                                    |
| `stl.table`    | Table manipulation utilities                                     |
| `stl.timer`    | Timer utilities                                                  |
| `stl.tmux`     | Tmux integration utilities                                       |
| `stl.winhint`  | Window hint display utilities                                    |

**Data Structures (`stl.c.*`):**

| Class               | Description                                              |
|:--------------------|:---------------------------------------------------------|
| `BatchDisposable`   | Batch disposal of multiple resources                     |
| `BatchHandler`      | Batch operation handler with error collection            |
| `CancellationToken` | Cooperative cancellation with callback support           |
| `CircularQueue`     | Fixed-size circular queue                                |
| `CircularStack`     | Fixed-size circular stack                                |
| `Dirtier`           | Dirty state tracking                                     |
| `Disposable`        | Resource cleanup abstraction                             |
| `Filetree`          | File tree with lazy loading                              |
| `Frecency`          | Frequency + recency based ranking                        |
| `Future`            | Promise-like async result with cancellation support      |
| `History`           | Navigation history with capacity limit                   |
| `InputHistory`      | Input field history management                           |
| `Observable`        | Reactive value container with subscription support       |
| `Proc`              | Process management                                       |
| `Scheduler`         | Throttle/debounce task scheduling                        |
| `Subscriber`        | Observer for Observable changes                          |
| `Subscribers`       | Collection of subscribers                                |
| `Theme`             | Theme management with highlight compilation              |
| `Ticker`            | Counter with subscription support                        |
| `Tree`              | Generic tree structure                                   |
| `TreeRetriever`     | Tree node retrieval helper                               |

### `lua/dot/` - Core Framework Layer

**Context System (`dot.context.*`):**

Persistent configuration with Observable-based state management:

| Scope        | Modules                                                                                                                                                    |
|:-------------|:-----------------------------------------------------------------------------------------------------------------------------------------------------------|
| `editor/`    | `behavior`, `theme` - Editor-wide settings                                                                                                                 |
| `session/`   | `tab` - Session-level settings                                                                                                                             |
| `workspace/` | `bookmark`, `colorpicker`, `explorer`, `flight`, `frecency`, `lsp`, `module`, `option`, `plugin`, `search_buffer`, `search_file`, `select`, `select_item` |

**Command System (`dot.command`):**

Definition-implementation separation pattern:

```lua
-- Define command (creates vim user command)
D.new("Fbufclose", "buf: close")

-- Implement command (can be tab-type specific)
M.implement({ uuid = "Fbufclose", tabtypes = stl.e.TabTypeSet.ALL, action = function() ... end })
M.implement({ uuid = "Fbufclose", tabtypes = stl.e.TabTypeSet.DIFFVIEW, action = function() ... end })

-- Execute command
dot.command.execute("Fbufclose")
```

**Core Modules:**

| Module        | Description                                                          |
|:--------------|:---------------------------------------------------------------------|
| `dot.buf`     | Buffer utilities (loadfile, resolve metadata, pick_filepath)         |
| `dot.win`     | Window utilities (is_sourcefile, pick_sourcefile, locate_symbols)    |
| `dot.tab`     | Tab utilities (resolve metadata, get_bufnrs)                         |
| `dot.path`    | Path utilities (workspace, cwd, locate_* helpers)                    |
| `dot.var`     | Constants (namespaces, signs, themes, togglers, zindex)              |
| `dot.session` | Session save/restore                                                 |
| `dot.lsp`     | LSP utilities                                                        |
| `dot.notifier`| Custom notification system                                           |

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

### `lua/era/` - Business Layer

**Modules (`era/m/`):**

Directory modules (with submodules):

| Module         | Description                                            |
|:---------------|:-------------------------------------------------------|
| `acp/`         | AI code panel                                          |
| `ai/`          | AI integration (config, prompt, types)                 |
| `clipboard/`   | Cross-platform clipboard (mac, win, wsl)               |
| `colorpicker/` | Color picker UI with format conversion                 |
| `explorer/`    | File explorer (node, view, types)                      |
| `git/`         | Git integration (state, buffer, repo, types)           |
| `im/`          | Input method management                                |
| `image/`       | Image display utilities                                |
| `lsp/`         | LSP utilities (types, symbol path finding)             |
| `minimap/`     | Minimap scrollbar                                      |
| `notepad/`     | Notepad widget                                         |
| `nvimbar/`     | Status/tab/window bar components                       |
| `picker/`      | Picker UI (finder, preview, composer)                  |
| `plugin/`      | Custom plugin loader (loader, state, view, types)      |
| `searcher/`    | Search and replace UI (finder, preview, composer)      |
| `select/`      | Selection UI                                           |
| `term/`        | Terminal management                                    |
| `toggle/`      | Feature toggle management                              |
| `ui_attach/`   | UI attach handlers                                     |
| `winsep/`      | Window separator styling                               |
| `wk/`          | Key binding manager (WhichKey)                         |

Single-file modules:

| Module            | Description                                        |
|:------------------|:---------------------------------------------------|
| `commentstring`   | Comment string detection                           |
| `copy`            | Copy utilities                                     |
| `dim`             | Window dimming                                     |
| `foldtext`        | Custom fold text                                   |
| `illuminate`      | Symbol highlighting under cursor                   |
| `input`           | Input UI component                                 |
| `inspect`         | Value inspection                                   |
| `lint`            | Linting integration                                |
| `maximize`        | Window maximize                                    |
| `notifier`        | Notification display                               |
| `python_venv`     | Python virtual environment detection               |
| `scroll`          | Smooth scrolling                                   |
| `splitline`       | Split line styling                                 |
| `statuscolumn`    | Custom status column                               |
| `statusline`      | Custom status line                                 |
| `tabline`         | Custom tab line                                    |
| `trailspace`      | Trailing whitespace highlighting                   |
| `virtcolumn`      | Virtual column display                             |
| `winline`         | Custom window line                                 |
| `winpicker`       | Window picker UI                                   |

**Functions (`era/fn/`):**

Standalone functions for common operations. Key functions include:

| Function                     | Description                                  |
|:-----------------------------|:---------------------------------------------|
| `find-buffers`               | Find open buffers                            |
| `find-diagnostics`           | Find diagnostics                             |
| `find-explorer`              | Find in explorer                             |
| `find-files`                 | Find files in workspace                      |
| `find-git`                   | Find git changes                             |
| `find-highlights`            | Find highlight groups                        |
| `find-keymaps`               | Find keymaps                                 |
| `find-lsp-symbols`           | Find LSP symbols                             |
| `find-notifications`         | Find notifications                           |
| `find-pinned-files`          | Find pinned files                            |
| `find-vim-options`           | Find vim options                             |
| `paste-image`                | Paste image from clipboard                   |
| `paste-image-as-base64`      | Paste image as base64                        |
| `pick-win`                   | Window picker                                |
| `refresh-all`                | Refresh all LSP clients                      |
| `rename`                     | File/symbol rename                           |
| `run-code`                   | Code runner                                  |
| `run-code-as-neovim-command` | Run code as Neovim command                   |
| `search-in-buffer`           | Search in current buffer                     |
| `search-in-files`            | Search and replace in files                  |
| `select-copy-filepath`       | Copy filepath with format selection          |
| `select-encoding`            | Select file encoding                         |

**Views (`era/view/`):**

| View            | Description                                      |
|:----------------|:-------------------------------------------------|
| `act`           | Action board                                     |
| `fileinfo`      | File information display                         |
| `filetree`      | File tree view                                   |
| `keysheet`      | Keymap reference                                 |
| `notifications` | Notification history view                        |
| `plainfile`     | Plain file renderer                              |
| `printer`       | Generic text printer                             |
| `setting`       | Settings UI                                      |
| `textarea`      | Text area component                              |
| `tree`          | Tree view renderer                               |

**Plugin Configs (`era/plugin/`):**

Individual plugin configurations: blink-cmp, flash, mini-*, nvim-dap, nvim-treesitter, etc.

### `lua/ark/` - Bootstrap Layer

Loaded before stl/dot, sets up global variables, patches, and workspace.

| File             | Description                                           |
|:-----------------|:------------------------------------------------------|
| `bootstrap.lua`  | Main bootstrap (sets _G.yoz, _G.stl, _G.dot)          |
| `autocmd.lua`    | Early autocommands                                    |
| `keymap.lua`     | Early keymaps                                         |
| `option.lua`     | Early options                                         |

**Vendor Entry Points (`ark/vendor/`):**

| Vendor      | Description                                                          |
|:------------|:---------------------------------------------------------------------|
| `neovim/`   | Standard Neovim setup                                                |
| `neovide/`  | Neovide GUI setup                                                    |
| `vscode/`   | VSCode extension setup                                               |

## Module Access Patterns

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
```

## Plugin Loader

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

## Rust-Lua Bridge

| Component        | Location                                              |
|:-----------------|:------------------------------------------------------|
| Compiled Library | `lua/yoz.so` (Unix) / `lua/yoz.dll` (Windows)         |
| Source Code      | `rust/yoz/src/`                                       |
| Build Command    | `./rust/build.sh --force`                             |

## Supporting Directories

| Directory        | Description                                           |
|:-----------------|:------------------------------------------------------|
| `ftplugin/`      | Filetype-specific settings                            |
| `lsp/`           | 21 language server configurations                     |
| `queries/`       | TreeSitter queries                                    |
| `rust/yoz/`      | Rust source code                                      |
| `doc/`           | Documentation and issue tracking                      |
| `lua/__types__/` | Type definitions for LSP                              |

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

## Data Flow

### Startup Flow

```
init.lua
    │
    ▼
ark/bootstrap.lua
    │
    ├── Set _G.yoz = require("yoz")
    ├── Set _G.stl = require("stl")
    ├── Apply patches (table.unpack, table.clear)
    ├── Setup shell and clipboard
    ├── Setup workspace (auto cd to git root)
    ├── Load ark/option, ark/keymap, ark/autocmd
    ├── Set _G.dot = require("dot")
    └── Set _G.era = require("era")
    │
    ▼
ark/vendor/{neovim,neovide,vscode}/init.lua
    │
    ├── Load dot autocmds
    ├── dot.setup_context() (restore persistent state)
    ├── Load vendor-specific options and keymaps
    ├── Load dressing (notifier, ui_attach)
    ├── Load commands
    ├── Load git module (if in git repo)
    ├── Load plugins
    ├── Restore session (if autosave enabled)
    │
    └── vim.schedule:
        ├── Load UI components (statusline, tabline, winline, etc.)
        ├── Setup breakpoints, diagnostics, LSP
        └── dot.context.watch_changes()
```

### State Persistence Flow

```
User Action (e.g., change theme)
    │
    ▼
Observable.next()
    │
    ▼
Subscriber callbacks
    │
    ├── UI updates (statusline, tabline redraw)
    │
    └── Ticker.tick()
            │
            ▼
        Scheduler (throttled, 256ms delay)
            │
            ▼
        dot.context.save()
            │
            ├── editor storage (theme, behavior)
            ├── session storage (tab state)
            └── workspace storage (bookmarks, LSP, etc.)
```

### Plugin Loading Flow

```
era.m.plugin.loader.setup(specs)
    │
    ▼
__register_plugins__()
    │
    └── Create plugin states, map modules to plugins
    │
    ▼
__install_package_loader__()
    │
    └── Insert custom loader in package.loaders
        (auto-loads plugin on require)
    │
    ▼
__load_plugins__()
    │
    └── For each spec:
        │
        ├── If lazy: __setup_lazy_loading__()
        │       │
        │       ├── event triggers (VeryLazy, BufRead, etc.)
        │       ├── cmd triggers (user commands)
        │       ├── ft triggers (FileType autocmd)
        │       └── keys triggers (keymap handlers)
        │
        └── If not lazy: __load_plugin__() immediately
    │
    ▼
__schedule_very_lazy__()
    │
    └── Fire User VeryLazy after UIEnter
```

**Plugin Load Sequence (`__load_plugin__`):**

```
1. Check cond() and enabled
2. Load dependencies recursively
3. Add to runtimepath
4. Source plugin/ directory (*.lua, *.vim)
5. Add after/ directory to runtimepath
6. Call config(spec, opts) or main.setup(opts)
7. Fire User PluginLoad autocmd
```

## Async Patterns

### Future and CancellationToken

The codebase uses `stl.c.Future` and `stl.c.CancellationToken` for async operations with cancellation support.

**Future States:**

| State       | Description                                      |
|:------------|:-------------------------------------------------|
| `pending`   | Operation in progress                            |
| `resolved`  | Completed successfully with result               |
| `rejected`  | Failed with error                                |
| `cancelled` | Cancelled via CancellationToken                  |

**Creating Futures:**

```lua
-- From callback-style function
local future = stl.c.Future.new({ token = token })
local cancel_fn = some_async_fn(function(result)
  future:__resolve__(result)
end)
if token then
  token:on_cancel(cancel_fn)
end

-- Using factory functions
local future = stl.c.Future.resolve(value)     -- Already resolved
local future = stl.c.Future.reject(error_msg)  -- Already rejected

-- With resolver function
local future, resolver = stl.c.Future.new_with_resolver({ token = token })
some_operation():finally(function(ok, result)
  resolver(result)
end)
```

**Consuming Futures:**

```lua
-- In async context
local result = future:await()

-- With callback
future:finally(function(ok, result)
  if ok then
    -- Handle success
  else
    -- Handle error/cancellation
  end
end)

-- Check state
if future:is_done() then ... end
if future:is_resolved() then ... end
if future:is_cancelled() then ... end
```

**CancellationToken Usage:**

```lua
-- Create token
local token = stl.c.CancellationToken.new()

-- Register cancel callback
local unsub = token:on_cancel(function()
  cleanup()
end)

-- Cancel operation
token:cancel()

-- Check in async functions
token:throw_if_cancelled()
```

**Async Utilities (`stl.async`):**

```lua
-- Run async function
stl.async.run(function()
  local result = some_future:await()
end)

-- Await multiple futures
local results = stl.async.await_all(futures)

-- Convert callback function to Future
local to_future = stl.async.to_future(arg_index, callback_fn)
local future = to_future(arg1, arg2)

-- With cancellation support
local to_future = stl.async.to_future_cancellable(arg_index, callback_fn, token)
```

