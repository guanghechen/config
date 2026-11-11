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

Every non-temporary Lua function, including module functions, methods, and named local helpers,
must declare at least one `---@return` annotation. Use the actual return types when values are
returned, and `---@return nil` when the function returns no values. Temporary inline anonymous
functions, such as callbacks and lambdas, may omit return annotations.

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

- Specs follow the [test architecture](design/test-harness.md): layout, harness, resource lifecycle and timing.
  Commands and an example spec are in `__test__/README.md`.
- Specs are not modules: they declare no `__module_name__`, start with their requires, without `Run with` lines,
  banners, or file-wide `---@diagnostic` comments, and end with `t:run()`.
- Support modules under `__test__/support/` follow the module pattern and annotation rules above.

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

## Rust Notes

- In `rust/yoz`, follow the existing `mlua` serialization/deserialization patterns and keep Lua-facing APIs
  synchronized with Lua call sites.
- Unit tests are named `t_*` and placed as the [test architecture](design/test-harness.md#rust-与-node-测试)
  describes.
