# AGENTS.md

This file provides guidance to Codex (OpenAI GPT-5) or any other autonomous agent when working with code in this repository.

## Project Overview

This is a sophisticated, deeply-customized Neovim configuration that combines Lua and Rust for enhanced performance. Rust-powered utilities are surfaced through the `yoz` native module, which exposes search, replace, filesystem, and string helpers to Lua. The architecture implements a completely custom framework with modular design patterns.

## Architecture

### Module Dependency Order

The modules follow a strict dependency hierarchy (lower layers must not depend on higher layers):

```
yoz → stl → dot → fml → vendor
```

- **yoz**: Rust-native standard library, completely independent Lua extension, does not depend on Neovim
- **stl**: Standard library with no external dependencies, may use `yoz` and `vim` global variables
- **dot**: Configuration, environment variables, utility functions, UX components; only depends on yoz/stl
- **fml**: Actions, dressing (UI styling and components), and plugin configurations
- **vendor**: Environment-specific entry points for neovim/neovide/vscode

### Global Variables

Three global variables are exposed via `_G`:
- `_G.yoz` → `require("yoz")` - Rust-powered helpers (set in `bot/init.lua`)
- `_G.stl` → `require("stl")` - Standard library for environment and dictionary (set in `bot/init.lua`)
- `_G.dot` → `require("dot")` - Configuration and core framework (set in `bot/init.lua`)

### Core Module Structure

#### `lua/yoz` - Rust Native Module
Compiled Rust native module (`.so` on Unix, `.dll` on Windows; no Lua wrapper).
- Exposes: `dict`, `fn`, `fs`, `path`, `replace`, `find`, `search`, `string`, `uri`
- Type definitions: `lua/__types__/yoz/`

#### `lua/stl/` - Standard Library Layer
Standard library with environment detection and dictionary data.

- **`stl/dict/`** - Dictionary data (e.g., `en` for English word pairs)
- **`stl/env`** - Environment detection (OS, terminal, paths)
- **`stl/external/`** - External utilities (`color`, `easing`)
- **`stl/fileicon`** - File icon definitions (directories, files, extensions, filetypes, LSP, OS)
- **`stl/filetype`** - Filetype constants and utility functions for file type detection
- **`stl/icon`** - Icon definitions (UI, diagnostics, LSP, DAP, Git, filetypes, etc.)
- **`stl/json`** - JSON utilities with comment stripping support
- **`stl/stdout`** - Colored stdout logging utilities
- **`stl/fn`** - Utility functions (boolean, identity, noop, equals, navigate, observe)
- **`stl/c/`** - Data structures and classes:
  - `BatchDisposable`, `BatchHandler` - Batch operations
  - `CircularQueue`, `CircularStack` - Circular data structures
  - `Dirtier`, `Disposable` - Resource management
  - `Filetree`, `Tree`, `TreeRetriever` - Tree structures
  - `Frecency`, `History`, `InputHistory` - Tracking utilities
  - `Observable`, `Subscriber`, `Subscribers` - Reactive patterns
  - `Proc`, `Scheduler`, `Ticker` - Process and timing
  - `Theme` - Theme management class

#### `lua/ark/` - Foundation Layer
Foundation layer with algorithms, collections, and utilities.

- **`ark/lang/`** - Language-specific utilities (`python`, `tailwind`)
- **`ark/view/`** - View renderers (`Plainfile`, `Printer`, `Tree`)

- **Core utilities**: `anim`, `box`, `debug`, `fs`, `hot`, `nvim`, `reporter`, `string`, `table`, `time`, `timer`, `tmux`, `var`, `winhint`

#### `lua/dot/` - Configuration and Core Framework Layer

- **`dot/context/`** - Persistent context management:
  - `editor/` - Editor-level settings (`behavior`, `theme`)
  - `session/` - Session-level settings (`tab`)
  - `workspace/` - Workspace-level settings (`bookmark`, `colorpicker`, `explorer`, `flight`, `frecency`, `lsp`, `module`, `option`, `plugin`, `search_buffer`, `search_file`, `select`, `select_item`)

- **`dot/fn/`** - Utility functions:
  - `add_locations_to_ai`, `paste_image`, `paste_image_as_base64`, `pick_win`, `rename`, `select_copy_filepath`, `select_copy_filepaths`, `select_encoding`

- **`dot/module/`** - Modular UI components:
  - `ai/` - AI integration (action, config, picker, proc, prompt, state, term, tmux, types)
  - `board/` - Information boards (act, fileinfo, git-hunk, keysheet)
  - `clipboard/` - Cross-platform clipboard (mac, nix, win, wsl)
  - `colorpicker/` - Color picker UI
  - `explorer/` - File explorer (node, resource/file, state, tree, types, view, widget)
  - `git/` - Git integration (blame, browse, buffer, cmd, diff, hunk, repo, sign, state, status, types, watcher)
  - `image/` - Image handling (convert, doc, image, inline, placement, state, terminal)
  - `im/` - Input method switching (mac, win, wsl)
  - `nvimbar/` - Status/tab/window bar components
  - `picker/` - Picker UI (composer/basic, composer/filetree, composer/list, composer/tree, finder, preview, result, view/filetree, view/tree)
  - `searcher/` - Search and replace UI (buffer, composer/basic, composer/filetree, finder, preview, result, view/filetree, view/plainfile)
  - `illuminate.lua` - Reference highlighting
  - `winpicker.lua` - Window picker

- **`dot/state/`** - Application state management:
  - `maximized`, `notepad/`, `qflist`, `status`, `widget`

- **`dot/theme/`** - Theme system:
  - `scheme/` - Color scheme definitions (18 schemes: catppuccin, gruvbox, nord, onehalf, rosepine, tokyonight, vsc variants)
  - `hlgroup/` - Highlight group definitions with theme-specific overrides (`catppuccin/`, `gruvbox/`, `onehalf/`, `tokyonight/`, `vsc/`)
  - Highlight group modules: `basic`, `common`, `lsp`, `module`, `nvimbar`, `plugin`, `treesitter`, `widget`

- **`dot/ux/`** - UX components (`select`, `setting`, `textarea`)
- **`dot/widget/`** - Widgets (`explorer`, `Notepad`, `Terminal`)

- **Core modules**: `G`, `autocmd`, `buf`, `command`, `lsp`, `lsp_action`, `notifier`, `path`, `session`, `shell`, `tab`, `term`, `uri`, `win`

#### `lua/fml/` - Frontend Configuration Layer

- **`fml/action/`** - Action handlers:
  - `ai.lua` - AI actions
  - `buf/` - Buffer actions (close, focus, new, pin, save, swap)
  - `code/` - Code actions (run, splitline)
  - `copy.lua` - Copy actions
  - `diagnostic.lua` - Diagnostic actions
  - `find/` - Find actions (buffers, diagnostics, explorer, files, git, highlights, keymaps, lsp_symbols, notification, pinned_files, vim_options)
  - `inspect.lua` - Inspection actions
  - `lint.lua` - Lint actions
  - `log.lua` - Log actions
  - `lsp/` - LSP actions (python_venv, reference, server)
  - `notepad.lua` - Notepad actions
  - `refresh.lua` - Refresh actions
  - `search/` - Search actions (buffer, files)
  - `session.lua` - Session actions
  - `tab/` - Tab actions (close, focus, new)
  - `term/` - Terminal actions (create, destroy, focus, lazygit, swap, yazi)
  - `toggle/` - Toggle actions (list, maximize/, theme)
  - `ux.lua` - UX actions
  - `win/` - Window actions (close, focus, history, mark, picker, resize, split)

- **`fml/dressing/`** - UI styling and rendering:
  - `commentstring.lua` - Comment string handling
  - `dim.lua` - Dim inactive windows
  - `foldtext.lua` - Fold text rendering
  - `im.lua` - Input method integration
  - `image.lua` - Image rendering
  - `input.lua` - Input UI
  - `lsp.lua` - LSP UI integration
  - `lsp_action.lua` - LSP action UI
  - `notifier.lua` - Notification system
  - `plugin.lua` - Plugin UI integration
  - `python_venv.lua` - Python venv UI
  - `scroll.lua` - Smooth scrolling
  - `select/` - Selection UI (codeaction, fallback, snacks providers)
  - `statuscolumn.lua` - Status column rendering
  - `statusline.lua` - Status line rendering
  - `tabline.lua` - Tab line rendering
  - `trailspace.lua` - Trailing space highlighting
  - `ui_attach/` - UI attach handlers (cmdline, messages, popupmenu, state)
  - `virtcolumn.lua` - Virtual column
  - `winline.lua` - Window line rendering
  - `winsep/` - Window separator styling

- **`fml/command.lua`** - Command definitions connecting `dot.command` to `fml.action`

- **`fml/action/plugin/`** - Plugin-specific actions (`diffview`, `mason`, `nvim-treesitter`)
- **`fml/cmp/`** - Completion configurations (`dict`, `path`)
- **`fml/plugins/`** - Individual plugin configurations:
  - blink-cmp, blink-indent, blink-pairs
  - conform, diffview, flash
  - mason, mini-ai, mini-hipatterns, mini-indentscope, mini-splitjoin, mini-surround
  - nvim-dap, nvim-dap-ui, nvim-dap-virtual-text, nvim-lint
  - nvim-treesitter, nvim-treesitter-context, nvim-treesitter-textobjects
  - render-markdown, which-key
- **`fml/plugin.lua`** - Plugin repository and lazy loading setup

#### `lua/ark/vendor/` - Environment-specific Entry Points

- **`ark/vendor/neovim/`** - Standard Neovim setup (`init`, `keymap`, `option`)
- **`ark/vendor/neovide/`** - Neovide GUI setup (`init`, `keymap`, `option`)
- **`ark/vendor/vscode/`** - VSCode extension setup (`action`, `init`, `keymap`, `option`)

#### `lua/ark/` - Bootstrap Module
Loaded before stl/dot, sets up `_G.yoz`, `_G.stl`, `_G.dot`, patches, shell, and workspace.
- `bootstrap.lua` - Main bootstrap
- `autocmd.lua`, `keymap.lua`, `option.lua` - Early configuration

#### Supporting Directories

- **`ftplugin/`** - Filetype-specific settings (`bigfile`, `gitcommit`, `html`, `jsonl`, `log`, `markdown`, `text`)
- **`lsp/`** - Language server configurations (21 servers)
- **`queries/`** - TreeSitter queries for various languages
- **`rust/yoz/`** - Rust source code for performance-critical operations
- **`doc/`** - Documentation and issue tracking
- **`lua/__types__/`** - Type definitions for LSP (`dot/`, `plugin/`, `stl/`, `yoz/`)

### Module Access Patterns

- `yoz.*` → Access Rust-native utilities directly (e.g., `yoz.path.*`, `yoz.fs.*`)
- `stl.c.Observable` → `require("stl.c.observable")` (collections mounted on stl.c)
- `dot.theme.scheme["catppuccin-mocha"]` → `require("dot.theme.scheme.catppuccin-mocha")`
- `dot.buf.*` → `require("dot.buf").*` (modules mounted directly via metatable)
- `dot.context.*`, `dot.state.*`, `dot.fn.*`, `era.view.*`, `era.widget.*` follow the same lazy-loading pattern
- `era.git.*`, `era.picker.*`, `era.searcher.*`, `era.board.*` → module subcomponents
- `dot.buf.retrieve_selected_text()` → returns the current visual selection text (empty when nothing selected)

### Vendor Entry Points

The configuration supports multiple environments through conditional loading in `init.lua`:
- **Standard Neovim**: `ark/vendor/neovim/` (default path)
- **Neovide GUI**: `ark/vendor/neovide/` (when `vim.g.neovide` is set)
- **VSCode Extension**: `ark/vendor/vscode/` (when `vim.g.vscode` is set)

Each vendor entry point includes environment-specific:
- `init.lua`: Main setup and loading sequence
- `option.lua`: Environment-specific options
- `keymap.lua`: Key mappings

The neovim vendor additionally loads:
- `dot.autocmd` - Core autocommands
- `fml.dressing.*` - UI dressing modules
- `fml.command` - Command implementations
- `era.git` - Git module (if in git repo)
- `fml.plugin` - Plugin management

### Rust-Lua Bridge

- **Compiled Library**: `lua/yoz` (`.so` on Unix, `.dll` on Windows)
- **Source Code**: `rust/yoz/src/` (mlua bridge)
  - Modules: `algorithm/`, `dict/`, `find/`, `fs/`, `path/`, `replace/`, `search/`, `string/`, `types/`, `uri/`
- **Build**: Run `./rust/build.sh --force` after Rust changes

## Code Conventions

### Neovim Version
- This configuration only supports the latest Neovim version; no backward compatibility code is needed

### Lua Code Standards
- Avoid unnecessary comments except typing comments like `---@type string`
- Use English in code and comments; avoid Chinese characters (except for special types, path links, or dict values)
- Use `vim.hl.range` API instead of deprecated `vim.api.nvim_buf_add_highlight`
- Use `vim.bo[bufnr].option` instead of deprecated `vim.api.nvim_buf_set_option()` and `vim.api.nvim_buf_get_option()`
- Use `dot.path.normalize` instead of `vim.fs.normalize` for path normalization, as it provides project-specific unified handling
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
  ---@alias era.git.StageState
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
Use `stl.reporter` for notifications instead of `vim.notify`:

```lua
stl.reporter.error({
  from = __module_name__,
  subject = "Operation Name",
  message = "Error message here",
  details = { key = "value" }, -- optional, displayed as JSON
})
-- Same interface for stl.reporter.{error|warn|info|debug}
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
- **Plugin Configs**: `fml/plugins/` for individual plugin configurations
- **Completion**: `fml/cmp/` for completion source configurations

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
- AI integration module with multiple providers
- Custom file explorer widget
- Notepad widget for scratch notes
- Comprehensive git integration (blame, hunk navigation, staging)
- Color picker with multiple format support
