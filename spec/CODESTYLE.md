# CODESTYLE.md

## Version Policy

- Only supports the latest Neovim version.
- Do not add backward compatibility branches unless explicitly requested.

## Naming Conventions

| Convention | Example                                       |
|:-----------|:----------------------------------------------|
| Buffer nr  | `bufnr` (not `buf`)                           |
| Window nr  | `winnr` (not `win`)                           |
| Tab nr     | `tabnr` (not `tab`)                           |
| Arrays     | `bufnrs`, `winnrs`, `tabnrs` (not `bufs`)     |

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
