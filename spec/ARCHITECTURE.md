# ARCHITECTURE.md

This document provides detailed architecture information for this Neovim configuration.

## Module Dependency Order

The modules follow a strict dependency hierarchy (lower layers must not depend on higher layers):

```text
yoz -> stl -> dot -> era -> ark/vendor
```

| Layer | Module   | Description                                                                 |
|:------|:---------|:----------------------------------------------------------------------------|
| L0    | `yoz`    | Rust-native library, independent Lua extension, no Neovim dependency        |
| L1    | `stl`    | Standard library, may use `yoz` and `vim` globals                           |
| L2    | `dot`    | Core framework: configuration, context, theme, commands; depends on yoz/stl |
| L3    | `era`    | Business layer: actions, UI modules, plugin configs; depends on yoz/stl/dot |
| L4    | `vendor` | Environment entry points: neovim/neovide/vscode                             |

## Global Variables

Four global variables are exposed via `_G` (set in `ark/bootstrap.lua`):

- `_G.yoz` -> `require("yoz")` (Rust-powered helpers)
- `_G.stl` -> `require("stl")` (standard library)
- `_G.dot` -> `require("dot")` (core framework)
- `_G.era` -> `require("era")` (business layer)

## Core Module Structure

### `rust/im` (Input Method Domain)

Standalone `yoz-im` crate owning macOS, Windows, and WSL input-method backends. It also owns the
repository-built Windows bridge used by WSL; the crate has no dependency on Lua or `rust/yoz`.

### `lua/yoz` (Rust Native Module)

Compiled Rust native module (`.so` on Unix, `.dll` on Windows; no Lua wrapper).

Submodules:

- `yoz.dict`: dictionary search for English word completion
- `yoz.find`: file finding (fd-like)
- `yoz.fn`: utility functions (uuid, md5)
- `yoz.fs`: filesystem operations (collect_files, readdir, move, get_filesize)
- `yoz.im`: Lua adapter for the `rust/im` source-oriented capture/restore contract
- `yoz.path`: path handling (normalize, join, relative, resolve, split, basename)
- `yoz.replace`: text replacement with regex support and preview
- `yoz.search`: content search (ripgrep-like, search_in_files, search_in_lines)
- `yoz.string`: string utilities
- `yoz.uri`: URI handling (encode/decode, filepath conversion)

Type definitions: `lua/__types__/yoz/`

### `lua/stl/` (Standard Library Layer)

`stl` is the shared runtime toolbox.

Key capabilities:

- Environment/runtime helpers (`stl.env`, `stl.shell`, `stl.tmux`)
- Common utilities (`stl.string`, `stl.table`, `stl.fs`, `stl.json`)
- OS boundary layer (`stl.os.path`, `stl.os.fs`) for filepath/os_path conversion and filesystem facade
- UI/runtime primitives (`stl.icon`, `stl.fileicon`, `stl.filetype`, `stl.reporter`)
- Async and state primitives in `stl.c.*` (`Observable`, `Future`, `Scheduler`, `History`, `Filetree`, etc.)

### `lua/dot/` (Core Framework Layer)

`dot` provides the project framework.

Key areas:

- Context system (`dot.context.*`) for persistent/editor/session/workspace state
- Command system (`dot.command`) with definition/implementation separation
- Core runtime helpers (`dot.buf`, `dot.win`, `dot.tab`, `dot.path`, `dot.var`, `dot.session`, `dot.lsp`)
- Theme and highlight composition (`dot.theme.*`)
- Runtime state (`dot.state.*`)

### `lua/era/` (Business Layer)

`era` contains user-facing features and UI modules.

Highlights:

- Feature modules in `era/m/*` (`explorer`, `picker`, `searcher`, `ai`, `git`, `term`, etc.)
- Callable functions in `era/fn/*` (`find-*`, `search-*`, `select-*`, `rename`, `run-code`, etc.)
- View components in `era/view/*` (`act`, `filetree`, `keysheet`, `notifications`, etc.)

## Entry Layer

`ark/vendor/*` contains environment entry points (neovim, neovide, vscode).

## Notes

- Keep dependencies one-way across layers.
- Prefer implementing shared logic in lower layers (`yoz`/`stl`/`dot`) only when it is truly reusable.
- For feature-specific behavior, keep logic in `era`.
