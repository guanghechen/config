# Plugin Module

## Overview

`era.m.plugin` is a lightweight plugin manager that provides lazy loading, update, and clean functionality. It serves as a simplified alternative to lazy.nvim with essential features.

## Features

- **Lazy Loading**: Load plugins on demand via events, commands, filetypes, or keymaps
- **Plugin Update**: Fetch and checkout latest commits from remote
- **Plugin Clean**: Remove unused plugin directories
- **Lock File**: Compatible with `lazy-lock.json` format
- **Unified Status View**: Show plugin inventory, startup profile, and inline operation progress

## Architecture

```
era.m.plugin/
├── init.lua     # Module entry and public API
├── types.lua    # Type definitions
├── state.lua    # Global state and configuration
├── loader.lua   # Plugin loading and lazy trigger setup
├── action.lua   # Install, update, clean, and build actions
├── view.lua     # Floating window management
└── widget.lua   # Unified status and operation rendering
```

### Module Dependencies

```
types.lua (pure types)
    ↓
state.lua (config, lock, specs)
    ↓
loader.lua (plugin loading)
    ↓
action.lua (install/update/clean/build)
    ↓
widget.lua (rendering)
    ↓
view.lua (window management)
    ↓
init.lua (public API)
```

## Configuration

```lua
---@class era.m.plugin.IConfig
---@field public lockfile               string       -- Lock file path
---@field public root                   string       -- Plugin install directory
---@field public ui                     era.m.plugin.IUIConfig

---@class era.m.plugin.IUIConfig
---@field public size                   { width: number, height: number }
---@field public border                 string       -- Border style
---@field public icons                  era.m.plugin.IIcons
```

## Plugin Spec

```lua
---@class era.m.plugin.IPluginSpec
---@field public name                   string           -- Plugin name (directory name)
---@field public url                    string|nil       -- Git repository URL
---@field public branch                 string|nil       -- Git branch
---@field public main                   string|nil       -- Main module name
---@field public cond                   (fun(): boolean)|nil  -- Condition function
---@field public enabled                boolean|nil      -- Enable/disable plugin
---@field public lazy                   boolean|nil      -- Lazy load flag
---@field public event                  string|string[]|nil   -- Event triggers
---@field public cmd                    string|string[]|nil   -- Command triggers
---@field public ft                     string|string[]|nil   -- Filetype triggers
---@field public keys                   IKeySpec[]|nil   -- Keymap triggers
---@field public dependencies           string[]|nil     -- Dependency plugin names
---@field public opts                   table|(fun(): table)|nil  -- Plugin options
---@field public config                 (fun(spec, opts): nil)|nil  -- Config function
```

## Usage

### Setup

```lua
local specs = {
  {
    name = "flash.nvim",
    main = "flash",
    event = { "VeryLazy" },
    opts = { ... },
  },
}

require("era.m.plugin").setup(specs)
```

### Commands

| Command   | Description               |
|:----------|:--------------------------|
| `:Plugin` | Open the plugin status UI |

### Keymaps (in plugin window)

| Key  | Description                |
|:-----|:---------------------------|
| `I`  | Install missing plugins    |
| `U`  | Update all plugins         |
| `X`  | Remove orphan plugins      |
| `gb` | Build the selected plugin  |
| `q`  | Close the window           |

## Status View

The plugin window has one stable surface. It displays:

- Neovim and startup-plugin timing summaries.
- Missing plugins and orphan directories before installed plugins.
- Startup plugins sorted by inclusive load time (slowest first).
- Runtime-loaded and not-loaded plugins as separate groups.
- Install, update, clean, and build tasks directly below their owning plugin or orphan row.

Completed no-op updates are omitted. Meaningful results and errors remain visible until the next operation replaces the task snapshot.

Startup profile semantics:

- `Neovim (UIEnter)` measures process start (`v:starttime`) through `UIEnter`.
- `Plugins (Startup)` measures top-level plugin load spans through `VeryLazy`.
- These metrics have different boundaries and are not additive.
- The snapshot is finalized after `VeryLazy`; plugins loaded by later runtime triggers are excluded.
- Plugin total counts nested dependencies once.
- Individual plugin times remain inclusive and may contain dependency load time.

Opening the window is read-only. Missing plugins are installed only after `I`; update and clean run only after `U` and `X` respectively.

## Highlight Groups

All highlight groups use the `m_pl_` prefix:

| Group             | Description            |
|:------------------|:-----------------------|
| `m_pl_h2`         | Section header         |
| `m_pl_bold`       | Bold text              |
| `m_pl_comment`    | Muted/comment text     |
| `m_pl_loaded`     | Loaded plugin icon     |
| `m_pl_not_loaded` | Not loaded plugin icon |
| `m_pl_running`    | Running task icon      |
| `m_pl_error`      | Error status           |
| `m_pl_time`       | Load time              |
| `m_pl_event`      | Event trigger          |
| `m_pl_cmd`        | Command trigger        |
| `m_pl_ft`         | Filetype trigger       |
| `m_pl_key`        | Key trigger            |
| `m_pl_dep`        | Dependency             |
| `m_pl_commit_from` | Old commit hash        |
| `m_pl_commit_to`  | New commit hash        |

## Lock File Format

Compatible with lazy.nvim's `lazy-lock.json`:

```json
{
  "plugin-name": { "branch": "main", "commit": "abc1234..." }
}
```

## Integration with fml/plugin.lua

```lua
---@type era.m.plugin.IRawSpec[]
local raw_specs = {
  { name = "flash.nvim", main = "flash", cond = conds.common },
  -- ...
}

-- Build full specs from raw specs
local specs = {}
for _, raw_spec in ipairs(raw_specs) do
  local spec = {
    url = "https://github.com/...",
    branch = "nvim@" .. raw_spec.name,
    name = raw_spec.name,
    main = raw_spec.main,
    cond = raw_spec.cond,
  }
  -- Load additional config from fml.plugin.*
  local ok, details = pcall(require, "fml.plugin." .. name)
  if ok then
    spec = vim.tbl_deep_extend("force", spec, details)
  end
  specs[#specs + 1] = spec
end

require("era.m.plugin").setup(specs)
```
