# AGENTS.md

This file provides guidance to Codex (OpenAI GPT-5) or any other autonomous agent when working with code in this repository.

## Project Overview

This is a sophisticated, deeply-customized Neovim configuration that combines Lua and Rust for enhanced performance. Rust-powered utilities are surfaced through the `rstd` native module, which exposes search, replace, filesystem, and string helpers to Lua. The architecture implements a completely custom framework with modular design patterns.

## Architecture

### Core Module Structure
- `lua/std/`: Foundation layer with algorithms, collections, and utilities
  - `std/collection/`: Data structures (Observable, Promise, Scheduler, etc.)
  - `std/lib/`: Library utilities (color, easing)
  - `std/types/`: Shared enums and theme/UX schemas used across modules
  - Core utilities: bootstrap, debug, fs, path, json, timer, etc.
- `lua/rstd/`: Rust-backed standard library surfaces
  - `rstd/fs`: File system utilities exposed via mlua bindings
  - `rstd/search`: Search operations that wrap Rust implementations
- `lua/eve/`: Core application framework
  - `eve/builtin/`: Core modules (G, ai, buf, clipboard, command, lsp, notifier, etc.)
  - `eve/constant/`: Constants and configurations (hlgroup themes, language configs)
  - `eve/context/`: Context management (editor, session, workspace)
  - `eve/state/`: Application state management
  - `eve/fn/`: Framework functions
  - `eve/ux/`: User experience components (picker, searcher, nvimbar, widgets)
- `lua/fml/`: Frontend configuration layer
  - `fml/action/`: Action handlers for various operations (buf, code, find, git, lsp, etc.)
  - `fml/dressing/`: UI styling and components (nvimbar, select, ui_attach, etc.)
  - `fml/command.lua`: Command definitions
- `lua/ghc/`: Plugin ecosystem
  - `ghc/cmp/`: Completion configurations
  - `ghc/plugins/`: Individual plugin configurations
  - `ghc/action/`: Plugin-specific actions
- `lua/integration/`: Environment-specific entry points
  - `integration/neovim/`: Standard Neovim setup
  - `integration/neovide/`: Neovide GUI setup
  - `integration/vscode/`: VSCode extension setup
- Supporting directories:
  - `queries/`: TreeSitter queries for various languages
  - `lsp/`: Language server configurations
  - `doc/`: Documentation and issue tracking
  - `bin/`: Compiled Rust binaries (platform-specific)

### Global Module Access Pattern

The configuration exposes core modules globally via `_G` for convenient access:

**Global Modules (accessible without require):**
- `_G.std` → `require("std")` - Foundation utilities
- `_G.rstd` → `require("rstd")` - Native Rust helpers (search, replace, filesystem, string)
- `_G.eve` → `require("eve")` - Core framework

**Module Access Patterns:**
- `std.*` → Access std utilities directly (e.g., `std.path.*`, `std.json.*`)
- `std.Observable` → `require("std.collection.observable")` (collections mounted directly)
- `eve.buf.*` → `require("eve.builtin.buf").*` (builtins mounted directly)
- `eve.constant.*` → `require("eve.constant").*`
- `eve.context.*` → `require("eve.context").*`
- `eve.state.*` → `require("eve.state").*`
- `eve.fn.*` → `require("eve.fn").*`
- `eve.ux.*` → `require("eve.ux").*`
- `eve.buf.retrieve_selected_text()` → helper that yanks the active visual selection (empty string when nothing selected)

### Integration Points
The configuration supports multiple environments through conditional loading in `init.lua`:
- **Standard Neovim**: `integration/neovim/` (default path)
- **Neovide GUI**: `integration/neovide/` (when `vim.g.neovide` is set)
- **VSCode Extension**: `integration/vscode/` (when `vim.g.vscode` is set)

Each integration includes environment-specific:
- `init.lua`: Main setup and loading sequence
- `option.lua`: Environment-specific options
- `keymap.lua`: Key mappings
- `autocmd.lua`: Auto commands (neovim only)

### Rust-Lua Bridge
- **Compiled Library**: `lua/rstd.so` (platform-specific binary)
- **Build Artifacts**: `bin/{osx,nix,win}.rstd.so` (platform builds)
- **Source Code**: `rust/rstd/` (mlua-powered integration)
- **Dependencies**: mlua 0.9 (luajit), regex, serde, chrono, uuid
- **Exposed Modules**: `rstd.fs`, `rstd.replace`, `rstd.find`, `rstd.search`, `rstd.string`, `rstd.fn`

## Development Commands

### Rust Development
Build the Rust components:
```bash
cd rust/rstd
cargo build --release
```

Force rebuild (recommended after Rust changes):
```bash
cd rust
./build.sh --force
```

The build script automatically:
- Detects platform (Darwin/Linux/Windows)
- Builds release version
- Copies to both `lua/rstd.so` and `bin/{platform}.rstd.so`
- Cleans up target directory

### Testing
- **Lua Tests**: Located in `__test__/__eve__/` (organized by module)
- **Rust Tests**: Run `cargo test` from `rust/rstd/`
- **Cheat Sheet**: 
  - prefer `./rust/build.sh --force && cargo test -p rstd` after touching native bindings.

## Code Conventions

### Lua Code Standards
- Avoid unnecessary comments except typing comments like `---@type string`
- Type annotations must start at column 41: `---@param name                          string`
- Use `vim.hl.range` API instead of deprecated `vim.api.nvim_buf_add_highlight`
- Format Lua with `stylua` using the repo `.stylua.toml` when making substantial edits.

### Error Reporting
Always use `std.reporter` for notifications and error messages instead of `eve.notifier.notify` or `vim.notify`:

```lua
-- Basic usage
std.reporter.error({
  from = __module_name__,
  subject = "Operation Name",
  message = "Error message here",
})

-- With additional details (will be formatted as JSON)
std.reporter.error({
  from = __module_name__,
  subject = "API Error",
  message = "Request failed",
  details = { status = 404, url = "/api/data" },
})

-- !!Strict same interfaces default level report for std.reporter.{error|warn|info|debug}
-- Options available:
-- - from: (required) Module name, usually __module_name__
-- - subject: (optional) Specific operation or context
-- - message: (optional) Main message text
-- - details: (optional) Additional data to be displayed as JSON
-- - group: (optional) Notification group
-- - anonymous: (optional) Hide sender info
-- - silent: (optional) Suppress notification display
```

### rstd Integration Notes
When modifying `rust/rstd/src/`:
- Follow existing mlua patterns for serialization/deserialization
- Keep Lua-facing APIs stable unless coordinating corresponding Lua updates
- Ensure type conversions remain efficient to preserve UI responsiveness

## Plugin Management
Plugins are managed using a custom plugin system:
- **Lock File**: `lazy-lock.json` contains exact plugin versions
- **Plugin Configs**: Individual configurations in `ghc/plugins/`
- **Completion**: CMP configurations in `ghc/cmp/`
- **Custom Forks**: Most plugins use forked versions with custom branches (prefixed with `nvim@`)
- **Key Plugins**: blink.cmp, conform.nvim, diffview.nvim, flash.nvim, nvim-treesitter, nvim-dap, etc.

**Plugin Loading**: Handled through integration-specific initialization sequences

## Initialization Sequence
1. **Bootstrap**: `std.bootstrap` sets up patches and workspace
2. **Global Modules**: Load `_G.std`, `_G.rstd`, `_G.eve`
3. **Logging**: Configure logging for git repositories
4. **Environment Detection**: Route to appropriate integration
5. **Context Setup**: Initialize eve context system
6. **UI Setup**: Load dressing, nvimbar components, theme
7. **Commands & Plugins**: Load commands and plugin system
8. **Session Recovery**: Auto-load sessions for git repositories

## Key Features
- **Performance**: Rust-powered search, file operations
- **Modularity**: Layered architecture with clear separation
- **Multi-Environment**: Supports Neovim, Neovide, VSCode
- **Session Management**: Automatic session handling for git repos
- **Custom UI**: Comprehensive status line, tab line, window line
- **Advanced UX**: Custom picker, searcher, and widget systems

## Development Files
- `init-theme.lua`: Theme testing and development
- `init-debug.lua`: Debug mode configuration
- `init-update.lua`: Update utilities
- `README.md`: Main documentation
- `doc/`: Issue tracking, design memos, and troubleshooting notes—scan it when you need historical decisions or open tasks.
