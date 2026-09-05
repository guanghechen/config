# CODESTYLE.md

## Version Policy

- Only supports the latest Neovim version.
- Do not add backward compatibility branches unless explicitly requested.

## Naming Conventions

| Convention | Example                                   |
| :--------- | :---------------------------------------- |
| Buffer nr  | `bufnr` (not `buf`)                       |
| Window nr  | `winnr` (not `win`)                       |
| Tab nr     | `tabnr` (not `tab`)                       |
| Arrays     | `bufnrs`, `winnrs`, `tabnrs` (not `bufs`) |

## API Preferences

```lua
-- Prefer vim.api over vim.fn
vim.api.nvim_get_current_buf()     -- not vim.fn.bufnr()
vim.api.nvim_get_current_win()     -- not vim.fn.winnr()

-- Prefer explicit variables over magic 0
local tabnr = vim.api.nvim_get_current_tabpage() ---@type integer
local winnrs = vim.api.nvim_tabpage_list_wins(tabnr) ---@type integer[]

-- Buffer/window options
vim.api.nvim_set_option_value("filetype", "lua", { buf = bufnr })
vim.api.nvim_get_option_value("modifiable", { buf = bufnr })
vim.api.nvim_set_option_value("number", false, { win = winnr, scope = "local" })

-- Path and highlight helpers
dot.path.normalize(filepath)        -- not vim.fs.normalize(filepath)
vim.hl.range(bufnr, ns, hlname, { row, col1 }, { row, col2 })
```

## Type Annotations

Column-aligned LuaLS annotations (column 40 style):

```lua
---@param name                          string
---@param callback                      fun(result: boolean): nil
---@return nil
```

Optional type rules:

- `---@param` / `---@field`: use `?` prefix
- `---@return` / `---@type`: use `|nil` suffix

Examples:

```lua
---@param token                         ?stl.c.CancellationToken
---@return integer|nil
local value = nil ---@type string|nil
```

## Module Pattern

Every module should define `__module_name__`:

```lua
---@diagnostic disable-next-line: unused-local
local __module_name__ = "era.m.example" ---@type string
```

Use `stl.reporter.{debug|info|warn|error}` for structured diagnostics.

## Lua Tests

- All tests and shared fixtures live under `__test__/`. Production `lua/` has no test-directory references or test-only hooks.
- Lua specs live under `__test__/specs/`, grouped by module and named `*_spec.lua`.
- Run all specs with `nvim -l __test__/run.lua`; append a literal path filter to run a directory or one spec.
- Use `__test__.support.harness` for cases, assertions, and cleanup. Each spec ends with `t:run()`.
- Use `__test__.support.bootstrap` for declared runtime globals. Composed runtime tests may explicitly load the application bootstrap.
- Register resource cleanup with `t:defer()` immediately after acquisition. Use `patch_global` / `patch_table` for mocks.
- Helpers stay beside the relevant cases until multiple specs need them; shared support lives under `__test__/support/`.
- Test behavior and failure paths; keep pure calculations, buffer state, and native rendering in focused specs.
- See `__test__/README.md` for commands and `spec/design/test-harness/` for the execution contract.

## Keymap Style

- Define keymaps with `stl.t.IKeymap[]`.
- Bind using `stl.nvim.fn.bindkeys`.
- Avoid introducing wrapper helpers for keymap creation unless there is strong justification.

Example:

```lua
---@type stl.t.IKeymap[]
local keymaps = {
  { modes = { "n" }, key = "<CR>", desc = "Select", callback = function() select() end },
  { modes = { "n" }, key = "q", desc = "Close", callback = function() close() end },
}

stl.nvim.fn.bindkeys(keymaps, {
  bufnr = bufnr,
  nowait = true,
  noremap = true,
  silent = true,
})
```

## Rust (`rust/yoz`) Notes

- Follow existing `mlua` serialization/deserialization patterns.
- Keep Lua-facing APIs synchronized with Lua call sites.
- Prefix Rust unit tests with `t_` (for example `fn t_parses_config()`).
- Put Rust test bodies in `__test__/rust/<crate>/**/*_test.rs`; source modules retain only `cfg(test)` include wiring, preserving module scope and platform gates. Format extracted files with `rustfmt --edition 2024`.
- Put Node specs in `__test__/node/*.test.mjs` and run them with `node --test`.
