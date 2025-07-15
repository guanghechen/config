# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Project Overview

This is a sophisticated Neovim configuration that combines Lua and Rust for enhanced performance. The configuration uses nvim-oxi to bridge Rust-powered utilities with Lua-based Neovim configuration.

## Architecture

### Core Module Structure
- `lua/std/`: Standard algorithms and collections (data structures, utilities)
- `lua/oxi/`: Lua interfaces for calling Rust methods via nvim-oxi and FFI
- `lua/eve/`: Common utilities and UX components (core framework)
- `lua/fml/`: Basic configs, keymaps, commands, and UI dressing
- `lua/ghc/`: Plugin-related configurations
- `lua/integration/`: Entry points for different Neovim environments (neovim, neovide, vscode)
- `queries/`: TreeSitter queries for syntax highlighting and parsing
- `rust/`: Rust source code for performance-critical operations

### Integration Points
The configuration supports multiple environments:
- Standard Neovim (`integration/neovim/`)
- Neovide GUI (`integration/neovide/`)
- VSCode extension (`integration/vscode/`)

## Development Commands

### Rust Development
Build the Rust components:
```bash
cd rust/nvim_tools
cargo build
```

Force rebuild:
```bash
cd rust/nvim_tools
./build.sh --force
```

Format Rust code:
```bash
cd rust/nvim_tools
cargo make format
```

## Code Conventions

### Lua Code Standards
- Avoid unnecessary comments except typing comments like `---@type string`
- Type annotations must start at column 41: `---@param name                          string`
- Use `vim.hl.range` API instead of deprecated `vim.api.nvim_buf_add_highlight`

### OXI Integration Rules
When modifying `lua/oxi/` or `rust/src/`:
- Reference nvim-oxi mechanic.rs example for proper Deserialization/Serialization patterns
- Ensure proper type handling between Rust and Lua boundaries

## Plugin Management
Plugins are managed through a custom system in `ghc/plugin.lua` with specifications stored in `lazy-lock.json`. The configuration uses forked versions of many plugins with custom branches (prefixed with `nvim@`).

## File Structure Notes
- Main entry point: `init.lua` (loads appropriate integration based on environment)
- Global modules exposed: `std`, `oxi`, `eve` (accessible as `_G.std`, `_G.oxi`, `_G.eve`)
- Session management and workspace context handled automatically for git repositories
- Custom UI components and dressing in `fml/dressing/`

## Testing
Run tests from the Rust directory using cargo make tasks. The test suite focuses on core functionality like ripgrep integration and text replacement operations.
