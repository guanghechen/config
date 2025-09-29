# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Project Overview

This is a sophisticated, deeply-customized Neovim configuration that combines Lua and Rust for enhanced performance. It uses nvim-oxi to bridge Rust-powered utilities with Lua-based Neovim configuration. The architecture implements a completely custom framework with modular design patterns.

## Architecture

### Core Module Structure
- `lua/std/`: Foundation layer with algorithms, collections, and utilities
  - `std/collection/`: Data structures (Observable, Promise, Scheduler, etc.)
  - `std/lib/`: Library utilities (color, easing)
  - Core utilities: bootstrap, debug, fs, path, json, timer, etc.
- `lua/oxi/`: Rust-Lua bridge interfaces via nvim-oxi
  - `oxi/finder`, `oxi/replacer`, `oxi/searcher`: Performance-critical search operations
  - `oxi/fs`, `oxi/string`: File system and string utilities
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
  - `rust/nvim_tools/`: Rust source code for performance-critical operations
  - `lsp/`: Language server configurations
  - `doc/`: Documentation and issue tracking
  - `bin/`: Compiled Rust binaries (platform-specific)

### Global Module Access Pattern

The configuration exposes core modules globally via `_G` for convenient access:

**Global Modules (accessible without require):**
- `_G.std` → `require("std")` - Foundation utilities
- `_G.oxi` → `require("oxi")` - Rust bridge interfaces
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
- `oxi.finder.*` → `require("oxi.finder").*` (Rust performance modules)

### Integration Points
The configuration supports multiple environments through conditional loading in `init.lua:14-24`:
- **Standard Neovim**: `integration/neovim/` (default path)
- **Neovide GUI**: `integration/neovide/` (when `vim.g.neovide` is set)
- **VSCode Extension**: `integration/vscode/` (when `vim.g.vscode` is set)

Each integration includes environment-specific:
- `init.lua`: Main setup and loading sequence
- `option.lua`: Environment-specific options
- `keymap.lua`: Key mappings
- `autocmd.lua`: Auto commands (neovim only)

### Rust-Lua Bridge
- **Compiled Library**: `lua/nvim_tools.so` (platform-specific binary)
- **Build Artifacts**: `bin/{osx,nix,win}.nvim_tools.so` (platform builds)
- **Source Code**: `rust/nvim_tools/` (nvim-oxi integration)
- **Dependencies**: nvim-oxi 0.6.0, regex, serde, chrono, uuid
- **Exposed Modules**: `oxi.finder`, `oxi.replacer`, `oxi.searcher`, `oxi.fs`, `oxi.string`

## Development Commands

### Rust Development
Build the Rust components:
```bash
cd rust/nvim_tools
cargo build --release
```

Force rebuild (recommended after Rust changes):
```bash
cd rust/nvim_tools
./build.sh --force
```

The build script automatically:
- Detects platform (Darwin/Linux/Windows)
- Builds release version
- Copies to both `lua/nvim_tools.so` and `bin/{platform}.nvim_tools.so`
- Cleans up target directory

### Testing
- **Lua Tests**: Located in `__test__/__eve__/` (organized by module)
- **Rust Tests**: Run `cargo test` from `rust/nvim_tools/`

## Code Conventions

### Lua Code Standards
- Avoid unnecessary comments except typing comments like `---@type string`
- Type annotations must start at column 41: `---@param name                          string`
- Use `vim.hl.range` API instead of deprecated `vim.api.nvim_buf_add_highlight`

### OXI Integration Rules
When modifying `lua/oxi/` or `rust/nvim_tools/src/`:
- Reference nvim-oxi examples for proper Deserialization/Serialization patterns
- Ensure proper type handling between Rust and Lua boundaries
- Follow the existing pattern in `oxi/` modules for FFI calls

## Plugin Management
Plugins are managed using a custom plugin system:
- **Lock File**: `lazy-lock.json` contains exact plugin versions
- **Plugin Configs**: Individual configurations in `ghc/plugins/`
- **Completion**: CMP configurations in `ghc/cmp/`
- **Custom Forks**: Most plugins use forked versions with custom branches (prefixed with `nvim@`)
- **Key Plugins**: blink.cmp, conform.nvim, diffview.nvim, flash.nvim, copilot.lua, nvim-treesitter, nvim-dap, etc.

**Plugin Loading**: Handled through integration-specific initialization sequences

## Initialization Sequence
1. **Bootstrap**: `std.bootstrap` sets up patches and workspace
2. **Global Modules**: Load `_G.std`, `_G.oxi`, `_G.eve`
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
- `doc/`: Issue tracking and detailed documentation
