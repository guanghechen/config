# ARCHITECTURE.md

This document provides detailed architecture information for this Neovim configuration.

## Module Dependency Order

The modules follow a strict dependency hierarchy (lower layers must not depend on higher layers):

```text
yoz -> stl -> dot -> era -> ark
```

`ux` sits beside `dot`: it depends only on `yoz`/`stl` and is used by `era`.

| Layer | Module   | Description                                                                 |
| :---- | :------- | :-------------------------------------------------------------------------- |
| L0    | `yoz`    | Rust-native library, independent Lua extension, no Neovim dependency        |
| L1    | `stl`    | Standard library, may use `yoz` and `vim` globals                           |
| L2    | `dot`    | Core framework: configuration, context, theme, commands; depends on yoz/stl |
| L2    | `ux`     | Treeview/Filetree Lua facades and Neovim surfaces; depends on yoz/stl       |
| L3    | `era`    | Business layer: actions, UI modules, plugin configs; depends on yoz/stl/dot |
| L4    | `ark`    | Entry layer: bootstrap, global options/keymaps/autocmds, vendor entries     |

## Global Variables

Four global variables are exposed via `_G` (set in `ark/bootstrap.lua`):

- `_G.yoz` -> `require("yoz")` (Rust-powered helpers)
- `_G.stl` -> `require("stl")` (standard library)
- `_G.dot` -> `require("dot")` (core framework)
- `_G.era` -> `require("era")` (business layer)

## Core Module Structure

### `rust/im` (Input Method Domain)

Standalone `yoz-im` crate owning macOS, Windows, and WSL input-method backends; the crate has no dependency on Lua or
`rust/yoz`. See [the input method design](design/feat/im.md).

### `rust/yoz/src/git` (Git Domain)

The `yoz::git` module owns cancellable Git status/ignore/blame queries, immutable snapshots, the ignore cache, and pure
staging calculations; core modules have no Lua or Neovim dependency. `era.m.git` owns editor lifecycle, refresh
scheduling, and presentation; see [the Git design](design/feat/git.md).

### `rust/yoz` (Rust Native Module)

Compiled Rust native module (`lua/yoz.so` on Unix, `lua/yoz.dll` on Windows; no Lua wrapper).

Submodules:

- `yoz.canonical_path`: slash-only canonical path operations and filepath/os_path conversion
- `yoz.dict`: dictionary search for English word completion
- `yoz.completion`: immutable candidate snapshots, Unicode fuzzy/typo matching, global ranking and acceptance history
- `yoz.find`: file finding (fd-like) on a cancellable parallel worker job
- `yoz.fuzzy`: fzf-style matching over native corpora: extended syntax, scoring, weighted ranking and Treeview id handles
- `yoz.fn`: utility functions (uuid, md5)
- `yoz.fs`: filesystem queries (collect_files, readdir, get_filesize, resource path helpers)
- `yoz.git`: asynchronous status/ignore/blame jobs, immutable snapshots, ignore cache and pure staging helpers
- `yoz.im`: Lua adapter for the `rust/im` source-oriented capture/restore contract
- `yoz.path`: path handling (normalize, join, relative, resolve, split, basename)
- `yoz.replace`: text replacement with regex support and preview
- `yoz.search`: content search (ripgrep-like, search_in_files, search_in_lines)
- `yoz.string`: string utilities
- `yoz.uri`: URI handling (encode/decode, filepath conversion)
- `yoz.ux`: native Treeview, Filetree, and Explorer interaction policy

Type definitions: `lua/__types__/yoz/`

### Treeview / Filetree / Explorer

Native implementations live in `rust/yoz/src/ux/`. The Treeview and Filetree Lua facades and Neovim surfaces
live in `lua/ux/`, using `yoz`, `stl`, and `vim`; this runtime layer does not depend on `dot` or `era`.
Explorer (`lua/era/m/explorer/`) and the other consumers live in `era`; see [Treeview](design/ux/treeview/README.md).

### `lua/stl/` (Standard Library Layer)

`stl` is the shared runtime toolbox.

Key capabilities:

- Environment/runtime helpers (`stl.env`, `stl.shell`, `stl.tmux`)
- Common utilities (`stl.string`, `stl.table`, `stl.fs`, `stl.json`)
- OS boundary layer (`stl.os.path`, `stl.os.fs`) for filepath/os_path conversion and filesystem facade
- UI/runtime primitives (`stl.icon`, `stl.fileicon`, `stl.filetype`, `stl.reporter`)
- Async and state primitives in `stl.c.*` (`Observable`, `Future`, `Scheduler`, `History`, `CancellationToken`, etc.)

### `lua/dot/` (Core Framework Layer)

`dot` provides the project framework.

Key areas:

- Context system (`dot.context.*`) for persistent editor/workspace state
- Command system (`dot.command`) with definition/implementation separation
- Core runtime helpers (`dot.buf`, `dot.win`, `dot.tab`, `dot.path`, `dot.var`)
- Theme and highlight composition (`dot.theme.*`)
- Runtime state (`dot.state.*`)

### `lua/era/` (Business Layer)

`era` contains user-facing features and UI modules.

Highlights:

- Feature modules in `era/m/*` (`explorer`, `picker`, `searcher`, `ai`, `git`, `term`, etc.)
- Completion in `era/keystroke/cmp/`: input sessions, sources, edit transactions and completion UI;
  see [the completion contract](design/feat/cmp.md).
- Callable functions in `era/fn/*` (`find-*`, `search-*`, `select-*`, `run-code`, etc.)
- View components in `era/view/*` (`act`, `result_tree`, `result_files`, `keysheet`, etc.)

## Entry Layer

`ark/vendor/*` contains environment entry points (neovim, neovide, vscode, yozvim, yuivim).

Yuivim sets `vim.g.yuivim` before `init.lua`; its entry, options and keymaps live independently under `ark/vendor/yuivim/`.
Yuivim and Yozvim leave UI, completion, LSP and Python environment management to the host.
Yuivim synchronously enables IM dressing and schedules splitjoin/surrounds setup; it skips plugin bootstrap,
commentstring and local plugin/dressing hooks. Yozvim leaves input-method management to the host.

## Notes

- Keep dependencies one-way across layers.
- Prefer implementing shared logic in lower layers (`yoz`/`stl`/`dot`) only when it is truly reusable.
- For feature-specific behavior, keep logic in `era`.
