# AGENTS.md

This file provides guidance to Codex (OpenAI GPT-5) or any other autonomous agent when working with code in this repository.

## Project Overview

This is a sophisticated, deeply-customized Neovim configuration that combines Lua and Rust for enhanced performance. Rust-powered utilities are surfaced through the `yoz` native module, which exposes search, replace, filesystem, and string helpers to Lua. The architecture implements a completely custom framework with modular design patterns.

## Architecture

### Module Dependency Order

The modules follow a strict dependency hierarchy (lower layers must not depend on higher layers):

```
yoz → ark → dot → fml → ghc → integration
```

- **yoz**: Rust-native standard library, completely independent Lua extension, does not depend on Neovim
- **ark**: Standard library with no external dependencies, may use `yoz` and `vim` global variables
- **dot**: Configuration, environment variables, utility functions, UX components; only depends on yoz/ark
- **fml**: Actions and dressing (UI styling and components)
- **ghc**: Plugin-related configurations
- **integration**: Environment-specific entry points for neovim/neovide/vscode

### Global Variables

Three global variables are exposed via `_G`:
- `_G.yoz` → `require("yoz")` - Rust-powered helpers (set in `bot/init.lua`)
- `_G.ark` → `require("ark")` - Foundation utilities and collections (set in `init.lua`)
- `_G.dot` → `require("dot")` - Configuration and core framework (set in `init.lua`)

### Core Module Structure

- `lua/yoz`: Compiled Rust native module (`.so` on Unix, `.dll` on Windows; no Lua wrapper)
  - Exposes: `dict`, `fn`, `fs`, `path`, `replace`, `find`, `search`, `string`
- `lua/ark/`: Foundation layer with algorithms, collections, and utilities
  - `ark/c/`: Data structures (Observable, Scheduler, History, Frecency, etc.)
  - Core utilities: env, fn, fs, nvim, reporter, string, table, timer, tmux, etc.
- `lua/dot/`: Configuration and core framework layer
  - `dot/context/`: Context management (editor, session, workspace)
  - `dot/state/`: Application state management (git, notepad, qflist, etc.)
  - `dot/theme/`: Theme system (schemes, highlight groups, namespace)
  - `dot/widget/`: Widgets (notepad, terminal)
  - `dot/ux/`: User experience components
    - `dot/ux/picker/`: Picker UI components
    - `dot/ux/searcher/`: Search and replace UI
  - Core modules: buf, command, git, lsp, lsp_action, notifier, path, session, tab, term, win, etc.
- `lua/fml/`: Frontend configuration layer
  - `fml/action/`: Action handlers (ai, buf, code, copy, diagnostic, find, git, lsp, search, tab, toggle, win)
  - `fml/dressing/`: UI styling (clipboard, input, lsp_action, nvimbar, scroll, select, statuscolumn, trailspace, ui_attach, virtcolumn, winsep)
  - `fml/command.lua`: Command definitions connecting dot.command to fml.action
- `lua/ghc/`: Plugin ecosystem
  - `ghc/cmp/`: Completion configurations
  - `ghc/plugins/`: Individual plugin configurations
  - `ghc/action/`: Plugin-specific actions
  - `ghc/plugin.lua`: Plugin repository and lazy loading setup
- `lua/integration/`: Environment-specific entry points
  - `integration/neovim/`: Standard Neovim setup
  - `integration/neovide/`: Neovide GUI setup
  - `integration/vscode/`: VSCode extension setup
- `lua/bot/`: Bootstrap module (loaded before ark/dot)
  - Sets up `_G.yoz`, patches, shell, and workspace
- Supporting directories:
  - `queries/`: TreeSitter queries for various languages
  - `rust/yoz/`: Rust source code for performance-critical operations
  - `lsp/`: Language server configurations
  - `doc/`: Documentation and issue tracking
  - `bin/`: Compiled Rust binaries (platform-specific)

### Module Access Patterns

- `yoz.*` → Access Rust-native utilities directly (e.g., `yoz.path.*`, `yoz.fs.*`)
- `ark.c.Observable` → `require("ark.c.observable")` (collections mounted on ark.c)
- `dot.buf.*` → `require("dot.buf").*` (modules mounted directly via metatable)
- `dot.context.*`, `dot.state.*`, `dot.fn.*`, `dot.ux.*`, `dot.widget.*` follow the same lazy-loading pattern
- `dot.buf.retrieve_selected_text()` → returns the current visual selection text (empty when nothing selected)

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
- Use `yoz.path.normalize` instead of `vim.fs.normalize` for path normalization, as it provides project-specific unified handling
- Use `bufnr` for buffer number variables (not `buf`), and `winnr` for window number variables (not `win`)
- Use `winnrs` for window number arrays (not `wins`)
- Use `vim.uv` directly instead of `vim.uv or vim.loop` fallback pattern
- Prefer `vim.api` over `vim.fn` when both provide equivalent functionality:
  - Use `vim.api.nvim_get_current_buf()` instead of `vim.fn.bufnr()`
  - Use `vim.api.nvim_get_current_win()` instead of `vim.fn.winnr()`
  - Use `vim.api.nvim_buf_get_lines()` instead of `vim.fn.getline()`
  - Use `vim.api.nvim_win_get_cursor()` instead of `vim.fn.getcurpos()`
  - Note: Some `vim.fn` functions have no `vim.api` equivalent (e.g., `vim.fn.foldclosed`, `vim.fn.mode`, `vim.fn.expand`, `vim.fn.fnamemodify`); these are acceptable
- Prefer explicit `tabnr`/`winnr` variables over magic number `0`:
  ```lua
  -- Bad
  local winnrs = vim.api.nvim_tabpage_list_wins(0)

  -- Good
  local tabnr = vim.api.nvim_get_current_tabpage() ---@type integer
  local winnrs = vim.api.nvim_tabpage_list_wins(tabnr) ---@type integer[]

  -- When tabnr is already available, use it to get winnr
  local winnr = vim.api.nvim_tabpage_get_win(tabnr) ---@type integer
  ```
- Add type annotations for primitive local variables:
  ```lua
  local bufnr = vim.api.nvim_get_current_buf() ---@type integer
  local name = "example" ---@type string
  local enabled = true ---@type boolean
  local winnrs = vim.api.nvim_tabpage_list_wins(tabnr) ---@type integer[]
  ```
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
  ---@alias dot.git.StageState
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

### Keymap Ordering
When defining keymaps in a list/table, follow this ordering:
1. Mouse keys (`<LeftMouse>`, `<2-LeftMouse>`, `<RightMouse>`, etc.)
2. `<M-*>` (Meta/Alt keys)
3. `<D-*>` (Command/Super keys)
4. `<C-a>*` (Ctrl-a prefix keys)
5. `<C-*>` (other Ctrl keys)
6. Special keys (`<CR>`, `<Tab>`, `<BS>`, `<Esc>`, etc.)
7. Uppercase letters (A-Z)
8. Lowercase letters (a-z)
9. Symbols and numbers

Within each category, sort alphabetically.

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
