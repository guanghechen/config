# Architecture Overview

This document provides a comprehensive overview of the Neovim configuration architecture.

## Module Hierarchy

```
┌─────────────────────────────────────────────────────────────────────────────────┐
│                              init.lua                                           │
│                   ark.bootstrap.setup() → sets _G.yoz, _G.stl, _G.dot           │
└─────────────────────────────────────────────────────────────────────────────────┘
                                        │
                                        ▼
┌─────────────────────────────────────────────────────────────────────────────────┐
│                         Vendor Entry Points                                     │
│  ┌───────────────────┐  ┌───────────────────┐  ┌───────────────────┐           │
│  │ ark/vendor/neovim │  │ ark/vendor/neovide│  │ ark/vendor/vscode │           │
│  │   (standard)      │  │   (GUI)           │  │   (extension)     │           │
│  └───────────────────┘  └───────────────────┘  └───────────────────┘           │
└─────────────────────────────────────────────────────────────────────────────────┘
```

## Layer Dependencies

```
Layer 4: ark/vendor    ─────────────────────────────────────────┐
                                                                 │
Layer 3: era           ─────────────────────────────────┐       │
         (business)                                      │       │
                                                         ▼       ▼
Layer 2: dot           ─────────────────────────┐      era     vendor
         (framework)                             │       │       │
                                                 ▼       │       │
Layer 1: stl           ─────────────────┐      dot ◄────┘       │
         (stdlib)                        │       │               │
                                         ▼       │               │
Layer 0: yoz           ──────────────  stl ◄────┘               │
         (rust)                          │                       │
                                         ▼                       │
                                        yoz ◄────────────────────┘
```

## Module Responsibilities

### Layer 0: `yoz` (Rust Native)

Performance-critical operations implemented in Rust:

| Module         | Responsibility                                    |
|:---------------|:--------------------------------------------------|
| `yoz.path`     | Path manipulation (normalize, join, relative)     |
| `yoz.fs`       | File system (collect_files, readdir, move)        |
| `yoz.search`   | Content search (ripgrep-like performance)         |
| `yoz.replace`  | Text replacement with preview                     |
| `yoz.string`   | String utilities (line width, parsing)            |
| `yoz.uri`      | URI encoding/decoding                             |
| `yoz.fn`       | Utilities (uuid, md5)                             |
| `yoz.dict`     | Dictionary for completion                         |
| `yoz.find`     | File finding (fd-like)                            |

### Layer 1: `stl` (Standard Library)

Foundation utilities with no external plugin dependencies:

| Module          | Responsibility                                   |
|:----------------|:-------------------------------------------------|
| `stl.env`       | Environment detection (OS, terminal, paths)      |
| `stl.fn`        | Utility functions (identity, noop, equals)       |
| `stl.reporter`  | Notification system                              |
| `stl.fs`        | File utilities (read/write JSON, watch)          |
| `stl.fileicon`  | File icon mappings                               |
| `stl.filetype`  | Filetype detection                               |
| `stl.icon`      | Icon definitions                                 |
| `stl.json`      | JSON with comment support                        |
| `stl.c.*`       | Data structures (see below)                      |

**Data Structures (`stl.c.*`):**

```
Observable ◄──── Subscriber
     │
     ▼
Subscribers ◄──── BatchDisposable ◄──── Disposable
     │
     ▼
Scheduler ◄──── Ticker
     │
     ▼
History ◄──── Frecency ◄──── InputHistory
     │
     ▼
Tree ◄──── Filetree ◄──── TreeRetriever
     │
     ▼
CircularQueue ◄──── CircularStack
     │
     ▼
Dirtier ◄──── BatchHandler ◄──── Proc
     │
     ▼
Theme
```

### Layer 2: `dot` (Core Framework)

Configuration, state management, and core abstractions:

| Module           | Responsibility                                  |
|:-----------------|:------------------------------------------------|
| `dot.buf`        | Buffer utilities and metadata                   |
| `dot.win`        | Window utilities and history                    |
| `dot.tab`        | Tab utilities and type detection                |
| `dot.path`       | Path utilities with workspace awareness         |
| `dot.command`    | Command definition and execution                |
| `dot.session`    | Session save/restore                            |
| `dot.lsp`        | LSP utilities                                   |
| `dot.notifier`   | Custom notification system                      |
| `dot.var`        | Constants and configurations                    |
| `dot.context.*`  | Persistent configuration                        |
| `dot.state.*`    | Runtime state                                   |
| `dot.theme.*`    | Theme and highlight system                      |

**Context System (`dot.context`):**

```
                    dot.context
                         │
        ┌────────────────┼────────────────┐
        ▼                ▼                ▼
    editor/          session/         workspace/
  (cross-session)   (per-session)    (per-workspace)
        │                │                │
        ├── behavior     └── tab          ├── bookmark
        └── theme                         ├── explorer
                                          ├── flight
                                          ├── frecency
                                          ├── lsp
                                          ├── option
                                          ├── plugin
                                          ├── search_*
                                          └── select
```

**Command System (`dot.command`):**

```
Define ──────► Definition Map ──────► vim.api.nvim_create_user_command()
                    │
                    ▼
Implement ────► Command Map ◄──────── tab-type specific implementations
                    │
                    ▼
Execute ──────► resolve by uuid + tabtype ──────► action()
```

### Layer 3: `era` (Business Layer)

UI components, actions, and plugin configurations:

| Module               | Responsibility                                   |
|:---------------------|:-------------------------------------------------|
| `era/m/picker/`      | Fuzzy finder UI                                  |
| `era/m/searcher/`    | Search and replace UI                            |
| `era/m/explorer/`    | File explorer widget                             |
| `era/m/nvimbar/`     | Status/tab/window bar                            |
| `era/m/git/`         | Git integration (blame, hunks, signs)            |
| `era/m/plugin/`      | Custom plugin loader                             |
| `era/m/ai/`          | AI integration                                   |
| `era/m/colorpicker/` | Color picker                                     |
| `era/m/term/`        | Terminal management                              |
| `era/fn/*`           | Action functions                                 |
| `era/view/*`         | View renderers                                   |
| `era/plugin/*`       | Plugin configurations                            |

### Layer 4: `ark/vendor` (Entry Points)

Environment-specific initialization:

| Vendor     | Entry Point                      | Description       |
|:-----------|:---------------------------------|:------------------|
| `neovim`   | `ark/vendor/neovim/init.lua`     | Standard Neovim   |
| `neovide`  | `ark/vendor/neovide/init.lua`    | Neovide GUI       |
| `vscode`   | `ark/vendor/vscode/init.lua`     | VSCode extension  |

## Key Patterns

### Lazy Loading via Metatable

```lua
-- lua/stl/init.lua
local M = setmetatable({}, {
  __index = function(t, k)
    local m = __mods[k]
    if m ~= nil then
      return require(m)  -- Load on first access
    end
    return rawget(t, k)
  end,
})
```

### Observable State

```lua
-- Create observable
local theme = stl.c.Observable.from_value("gruvbox-dark")

-- Subscribe to changes
theme:subscribe(stl.c.Subscriber.new({
  on_next = function(value, prev_value)
    -- React to change
  end,
}))

-- Update value (triggers subscribers)
theme:next("tokyonight")

-- Read current value
local current = theme:snapshot()
```

### Resource Cleanup

```lua
-- Disposable pattern
local disposable = stl.c.Disposable.new({
  on_dispose = function()
    -- Cleanup logic
  end,
})

-- Batch disposal
local batch = stl.c.BatchDisposable.new()
batch:add(disposable1)
batch:add(disposable2)
batch:dispose()  -- Disposes all
```

### Command System

```lua
-- 1. Define command (in dot/command.lua)
D.new("Fbufclose", "buf: close")

-- 2. Implement command (in era/command.lua)
M.implement({
  uuid = "Fbufclose",
  action = function()
    -- Close buffer logic
  end,
})

-- 3. Tab-specific implementation
M.implement({
  uuid = "Fbufclose",
  tabtype = "terminal",
  action = function()
    -- Different logic for terminal tabs
  end,
})

-- 4. Execute
dot.command.execute("Fbufclose")
-- or
dot.command.definitions.buf.close:execute()
```

## File Organization

```
lua/
├── yoz.so                 # Rust compiled module
├── __types__/             # LuaLS type definitions
│   ├── yoz/               # Rust module types
│   ├── stl/               # Standard library types
│   ├── dot/               # Framework types
│   └── plugin/            # Plugin types
├── ark/                   # Bootstrap layer
│   ├── bootstrap.lua      # Main entry
│   ├── autocmd.lua        # Early autocommands
│   ├── keymap.lua         # Early keymaps
│   ├── option.lua         # Early options
│   └── vendor/            # Environment entry points
├── stl/                   # Standard library
│   ├── init.lua           # Module exports
│   ├── c/                 # Data structures
│   ├── dict/              # Dictionary data
│   ├── nvim/              # Neovim utilities
│   └── external/          # External utilities
├── dot/                   # Core framework
│   ├── init.lua           # Module exports
│   ├── context/           # Persistent config
│   │   ├── editor/        # Cross-session
│   │   ├── session/       # Per-session
│   │   └── workspace/     # Per-workspace
│   ├── state/             # Runtime state
│   └── theme/             # Theme system
│       ├── scheme/        # Color schemes
│       └── hlgroup/       # Highlight groups
└── era/                   # Business layer
    ├── m/                 # UI modules
    │   ├── picker/
    │   ├── searcher/
    │   ├── explorer/
    │   ├── nvimbar/
    │   ├── git/
    │   └── plugin/
    ├── fn/                # Action functions
    ├── view/              # View renderers
    └── plugin/            # Plugin configs
```

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
    ├── Set _G.dot = require("dot")
    ├── Apply patches
    └── Detect workspace
    │
    ▼
ark/vendor/{neovim,neovide,vscode}/init.lua
    │
    ├── Load options
    ├── Load keymaps
    ├── Load autocmds
    ├── Load dressing (UI components)
    ├── Load commands
    ├── Load git module (if in repo)
    └── Load plugins
    │
    ▼
dot.context.load()
    │
    └── Restore persistent state
    │
    ▼
dot.context.watch_changes()
    │
    └── Subscribe to state changes
```

### State Persistence Flow

```
User Action
    │
    ▼
Observable.next()
    │
    ▼
Subscriber callbacks
    │
    ├── UI updates (statusline, etc.)
    │
    └── Scheduler (throttled)
            │
            ▼
        dot.context.save()
            │
            ├── editor.json (theme, behavior)
            ├── session.json (tab state)
            └── workspace.json (bookmarks, LSP, etc.)
```

### Plugin Loading Flow

```
era.m.plugin.setup(specs)
    │
    ▼
Register plugins in state
    │
    ▼
Install package loader (package.loaders)
    │
    ▼
For each spec:
    │
    ├── If lazy: setup triggers (event, cmd, ft, keys)
    │       │
    │       └── On trigger: load_plugin()
    │
    └── If not lazy: load_plugin() immediately
    │
    ▼
load_plugin():
    │
    ├── Load dependencies first
    ├── Add to runtimepath
    ├── Source plugin/ directory
    ├── Call config() or main.setup()
    └── Fire User PluginLoad autocmd
```
