# GEMINI.md

This file provides guidance to Gemini (Google DeepMind) when working with code in this repository.

## Supreme Principles

> **Non-negotiable.** Violation of these principles is unacceptable.

### User Profile
1. **Git Expert** - Never modify staging area or branches autonomously (`git add/reset/stash/checkout/restore/commit`). Always ask for confirmation or provide shell commands for the user to execute.
2. **Code Perfectionist** - Produce elegant, minimal code. Follow guidelines strictly.
3. **Language** - **Respond in Chinese**; keep technical terms/jargon in their original language (usually English).

### Critical Rules
1. **CRITICAL**: Never read git-ignored files unless path explicitly given.
2. **CRITICAL**: Never access secrets (`.env*`, `*credentials*`, `.ssh/`, `*.http_request`, `*.http_response`).
3. **CRITICAL**: Adhere to the strict module dependency hierarchy (L0 -> L1 -> L2 -> L3 -> L4).

## Project Overview

This is a sophisticated, deeply-customized Neovim configuration that combines Lua and Rust for enhanced performance. Rust-native helpers are exposed through the `yoz` module, giving Lua fast search, replace, filesystem, and string utilities.

## Architecture

### Module Dependency Order

Modules follow a strict dependency hierarchy. Lower layers must **never** depend on higher layers.

```
yoz (L0) → stl (L1) → dot (L2) → era (L3) → ark/vendor (L4)
```

| Layer | Module   | Description                                                                   |
|:------|:---------|:------------------------------------------------------------------------------|
| L0    | `yoz`    | Rust-native library, independent Lua extension, no Neovim dependency          |
| L1    | `stl`    | Standard library, may use `yoz` and `vim` globals                             |
| L2    | `dot`    | Core framework: configuration, context, theme, commands; depends on yoz/stl   |
| L3    | `era`    | Business layer: actions, UI modules, plugin configs; depends on yoz/stl/dot   |
| L4    | `vendor` | Environment entry points: neovim/neovide/vscode                               |

### Global Variables

Three global variables are exposed via `_G` (set in `ark/bootstrap.lua`):
- `_G.yoz` → `require("yoz")` - Rust-powered helpers
- `_G.stl` → `require("stl")` - Standard library
- `_G.dot` → `require("dot")` - Core framework

## Coding Conventions

### Lua Style & Structure

1. **Type Annotations**:
   - All public APIs must have LuaLS annotations.
   - **Alignment**: Align types/descriptions at column 40.
   - **Class Fields**: Must specify visibility (`public`, `protected`, `private`).

   ```lua
   ---@param name                        string
   ---@param callback                    fun(result: boolean): nil
   ---@return nil

   ---@class foo.MyClass
   ---@field public name                 string
   ---@field protected _internal         integer
   ```

2. **Protected Methods**:
   - Naming: `__method_name__`
   - Location: Place at the end of the file/class.
   - Separator: Use a 100-character dash line before the protected section.

   ```lua
   function M.public_method() end

   ----------------------------------------------------------------------------------------------------

   function M.__protected_method__() end
   ```

3. **Variable Naming**:
   - Use `bufnr`, `winnr`, `tabnr` (not `buf`, `win`, `tab`).
   - Arrays: `bufnrs`, `winnrs` (not `bufs`).
   - Interfaces: `I`-prefixed (e.g., `IChatMessage`, `IUser`).

4. **API Preferences**:
   - Use `vim.api` over `vim.fn` where possible.
   - Use `vim.uv` over `vim.loop`.
   - Use project utilities:
     - `dot.path.normalize` over `vim.fs.normalize`.
     - `stl.reporter.error` over `vim.notify`.

5. **Error Reporting**:
   - Define `local __module_name__ = "path.to.module"` at the top.
   - Use `stl.reporter` with structured data.

   ```lua
   stl.reporter.error({
     from = __module_name__,
     subject = "Operation Failed",
     message = "Details...",
     details = { error = err },
   })
   ```

### Rust Integration

- Source: `rust/yoz/src/`
- Build: `./rust/build.sh --force`
- Lua Bridge: Keep Lua-facing APIs synchronized with `yoz` Lua definitions (`lua/__types__/yoz/`).
- Tests: Prefix unit test functions with `t_`.

## Workflow Guidelines

1. **Understand First**: Use `search_file_content` and `glob` to map dependencies before editing.
2. **Architecture Check**: Verify which layer (L0-L4) you are working in. Do not introduce upward dependencies.
3. **Rust Changes**: If modifying Rust code, always run `./rust/build.sh --force` to verify compilation.
4. **Lua Formatting**: Ensure code is formatted (trailing newline, aligned types).
5. **Completion**: Do not leave TODOs or half-implemented features unless explicitly instructed.

## Documentation

- **Markdown**: Align tables (CJK characters = 2 units, ASCII = 1 unit).
- **Trailing Newline**: Ensure a single trailing newline at the end of every file.
