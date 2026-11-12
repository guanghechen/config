---@diagnostic disable-next-line: unused-local
local __module_name__ = "__test__.support.ark_autocmd" ---@type string

-- `lua/ark/autocmd.lua` creates its autocommands as it loads, each in a group of its own.

local M = {}

---Records each autocommand created from now on in `autocmds` and its event in `events`, both by group, instead of
---creating it, until the case ends or the returned function stops the recording. Creating a group meanwhile returns
---its name.
---@param t                             __test__.support.Harness
---@param autocmds                      table<string, table>
---@param events                        table<string, string|string[]>
---@return fun()
function M.record(t, autocmds, events)
  local restore_augroup = t:patch_table(vim.api, "nvim_create_augroup", function(name)
    return name
  end)
  local restore_autocmd = t:patch_table(vim.api, "nvim_create_autocmd", function(event, opts)
    autocmds[opts.group] = opts
    events[opts.group] = event
    return 1
  end)
  return function()
    restore_autocmd()
    restore_augroup()
  end
end

---Loads `lua/ark/autocmd.lua` without registering its autocommands, and returns them and their events by group. Only
---the module's own autocommands are recorded: those the runtime creates later in the case, such as the `syntaxset`
---group Treesitter highlighting creates when it loads syntax, are created as usual.
---@param t                             __test__.support.Harness
---@return table<string, table> autocmds
---@return table<string, string|string[]> events
function M.load(t)
  local autocmds, events = {}, {} ---@type table<string, table>, table<string, string|string[]>
  local stop = M.record(t, autocmds, events)
  assert(loadfile("lua/ark/autocmd.lua"))()
  stop()
  return autocmds, events
end

return M
