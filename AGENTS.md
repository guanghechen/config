# AGENTS.md

This file provides guidance to Codex (OpenAI GPT-5) or any other autonomous agent when working with code in this repository.

## Project Overview

This is a sophisticated, deeply-customized Neovim configuration that combines Lua and Rust for enhanced performance. Rust-powered utilities are surfaced through the `yoz` native module, which exposes search, replace, filesystem, and string helpers to Lua. The architecture implements a completely custom framework with modular design patterns.

## Architecture

### Core Module Structure
- `lua/std/`: Foundation layer with algorithms, collections, and utilities
  - `std/collection/`: Data structures (Observable, Scheduler, etc.)
  - `std/lib/`: Library utilities (color, easing)
  - `std/source/`: Notepad data source implementations (json, folder)
  - `std/types/`: Shared type definitions (common, enum, notepad, theme, ux)
  - Core utilities: bootstrap, debug, fs, path, json, timer, etc.
- `lua/yoz`: Compiled Rust native module (`.so` on Unix, `.dll` on Windows; no Lua wrapper)
  - Exposes: `dict`, `fn`, `fs`, `path`, `replace`, `find`, `search`, `string`
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
  - `rust/yoz/`: Rust source code for performance-critical operations
  - `lsp/`: Language server configurations
  - `doc/`: Documentation and issue tracking
  - `bin/`: Compiled Rust binaries (platform-specific)

### Global Module Access Pattern

The configuration exposes core modules globally via `_G` for convenient access:

**Global Modules (accessible without require):**
- `_G.std` → `require("std")` - Foundation utilities
- `_G.yoz` → `require("yoz")` - Native Rust helpers (search, replace, filesystem, string)
- `_G.eve` → `require("eve")` - Core framework

**Module Access Patterns:**
- `std.*` → Access std utilities directly (e.g., `std.path.*`, `std.json.*`)
- `std.Observable` → `require("std.collection.observable")` (collections mounted directly)
- `eve.buf.*` → `require("eve.builtin.buf").*` (builtins mounted directly)
- `eve.constant.*`, `eve.context.*`, `eve.state.*`, `eve.fn.*`, `eve.ux.*` follow the same pattern
- `eve.buf.retrieve_selected_text()` → returns the current visual selection text (empty when nothing selected)

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
- **Compiled Library**: `lua/yoz` (`.so` on Unix, `.dll` on Windows)
- **Source Code**: `rust/yoz/` (mlua integration)
- **Build**: Run `./rust/build.sh --force` after Rust changes

## Code Conventions

### Neovim Version
- This configuration only supports the latest Neovim version; no backward compatibility code is needed

### Lua Code Standards
- Avoid unnecessary comments except typing comments like `---@type string`
- Use English in code and comments; avoid Chinese characters (except for special types, path links, or dict values)
- Use `vim.hl.range` API instead of deprecated `vim.api.nvim_buf_add_highlight`
- Use `vim.bo[bufnr].option` instead of deprecated `vim.api.nvim_buf_set_option()` and `vim.api.nvim_buf_get_option()`
- Use `std.path.normalize` instead of `vim.fs.normalize` for path normalization, as it provides project-specific unified handling
- Use `bufnr` for buffer number variables (not `buf`), and `winnr` for window number variables (not `win`)
- Use `vim.uv` directly instead of `vim.uv or vim.loop` fallback pattern
- Format Lua with `stylua` using the repo `.stylua.toml` when making substantial edits

### Type Annotation Formatting
- Type annotations must start at column index 40 (0-indexed, i.e., the 41st character from line start):
  ```lua
  ---@param name                        string
  ---@param callback                    fun(result: boolean): nil
  ---@return nil
  ```
- Union type aliases must have each union item on its own line with `---| ` prefix, using double quotes for string literals:
  ```lua
  ---@alias std.git.StageState
  ---| "staged"
  ---| "unstaged"
  ---| "mixed"
  ---| nil
  ```
- For multi-line target objects, place `---@type` annotation **above** the target, not after:
  ```lua
  -- Bad
  local config = create_config({
    key = "value",
  }) ---@type IConfig

  -- Good
  ---@type IConfig
  local config = create_config({
    key = "value",
  })
  ```
- Class field annotations must include a visibility modifier (`public`, `protected`, or `private`) and follow the same column index 40 alignment:
  ```lua
  ---@class foo.bar.MyClass
  ---@field public name                 string
  ---@field public callback             fun(): nil
  ---@field protected _internal         integer
  ```
- Avoid using `private`; prefer `protected` for non-public fields
- Adjacent type definitions (`---@alias` or `---@class`) must be separated by at least one blank line:
  ```lua
  -- Bad
  ---@alias foo.TypeA string
  ---@alias foo.TypeB number

  -- Good
  ---@alias foo.TypeA string

  ---@alias foo.TypeB number
  ```

### Class Field/Method Visibility
- All `@field` annotations must have a visibility modifier: `public`, `protected`, or `private`
- Prefer `protected` over `private` for non-public class fields and methods
- Protected methods must use `__<method_name>__` naming convention
- Protected methods must be placed at the end of the class (fields are not affected by this rule)
- Add a 100-character dash separator line above the first protected method:
  ```lua
  ---@class foo.bar.Example
  local M = {}

  function M.public_method_alpha()
  end

  function M.public_method_beta()
  end

  ----------------------------------------------------------------------------------------------------

  function M.__protected_method_alpha__()
  end

  function M.__protected_method_beta__()
  end
  ```
- Protected methods should be ordered alphabetically

### Error Reporting
Use `ark.reporter` for notifications instead of `vim.notify`:

```lua
ark.reporter.error({
  from = __module_name__,
  subject = "Operation Name",
  message = "Error message here",
  details = { key = "value" }, -- optional, displayed as JSON
})
-- Same interface for ark.reporter.{error|warn|info|debug}
```

### Rust Integration
When modifying `rust/yoz/src/`:
- Follow existing mlua patterns for serialization/deserialization
- Keep Lua-facing APIs synchronized with Lua call sites
- Prefix Rust unit test function names with `t_` (e.g., `fn t_parses_config()`)

## Plugin Management
- **Lock File**: `lazy-lock.json` contains exact plugin versions
- **Plugin Configs**: `ghc/plugins/` for individual plugin configurations
- **Completion**: `ghc/cmp/` for completion source configurations

## Development Files
- `init-theme.lua`: Theme testing and development
- `init-update.lua`: Update utilities
- `README.md`: Main documentation
- `doc/`: Issue tracking and detailed documentation

## Key Features
- Rust-powered search, replace, and file operations for performance
- Multi-environment support: Neovim, Neovide, VSCode
- Automatic session management for git repositories
- Custom UI components: status line, tab line, window line, picker, searcher
