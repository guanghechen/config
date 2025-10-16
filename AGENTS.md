# Repository Guidelines

## Project Structure & Module Organization
- Core Lua sources live under `lua/`, split into foundation (`lua/std`), Rust bridges (`lua/oxi`), the `eve` framework, frontend layer `lua/fml`, plugin ecosystem `lua/ghc`, and environment adapters `lua/integration`.
- Rust performance code resides in `rust/nvim_tools/`; compiled artifacts land in `lua/nvim_tools.so` and `bin/{osx,nix,win}.nvim_tools.so`.
- TreeSitter queries (`queries/`), LSP setups (`lsp/`), documentation (`doc/`), and tests (`__test__/__eve__/`) are maintained alongside Lua sources.

## Build, Test, and Development Commands
- `cd rust/nvim_tools && cargo build --release` builds the Rust bridge for local testing.
- `cd rust/nvim_tools && ./build.sh --force` performs a clean rebuild and syncs the `.so` payloads into `lua/` and `bin/`.
- Lua test suites run from the repo root with `nvim --headless -c "PlenaryBustedDirectory __test__/__eve__" -c qa` or within Neovim via the project’s test runner.
- Rust unit tests execute with `cd rust/nvim_tools && cargo test`.

## Coding Style & Naming Conventions
- Lua modules use snake_case filenames and expose globals via `_G.std`, `_G.oxi`, and `_G.eve`; mount new utilities under those namespaces.
- Follow existing indentation: 2 spaces for Lua, 4 spaces for Rust and JSON; keep ASCII unless a file already diverges.
- Prefer expressive module-local constants in `eve.constant` and route user messaging through `std.reporter.{error,warn,info,debug}`.
- Lua type annotations start at column 41 (`---@param name                          string`); avoid redundant inline comments.

## Testing Guidelines
- Mirror module paths in test directories (e.g., `__test__/__eve__/ux/picker_spec.lua` for `lua/eve/ux/picker.lua`).
- Write deterministic tests; prefer fixtures from `std.fs` helpers over ad-hoc paths.
- Ensure Rust additions include `#[cfg(test)]` modules and, when FFI changes occur, cover Lua integration in `__test__/__eve__/`.

## Commit & Pull Request Guidelines
- Use imperative, scope-prefixed commit subjects (`eve.buf: add range validator`); reference module paths when possible.
- Highlight cross-language changes (Lua ↔ Rust) in the body and mention any required rebuilds of `nvim_tools.so`.
- Pull requests should summarize behavioral impact, list verification steps (tests, builds), and link related issues; include screenshots or asciinema for UX tweaks.

## Rust-Lua Bridge Notes
- When touching `lua/oxi` or `rust/nvim_tools`, confirm serialization boundaries follow existing `nvim-oxi` patterns and rerun the force build script.
- Keep ABI stability in mind: bump consumers in `eve` or `fml` when modifying exposed Rust signatures.
