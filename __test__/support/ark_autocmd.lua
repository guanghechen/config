---@diagnostic disable-next-line: unused-local
local __module_name__ = "__test__.support.ark_autocmd" ---@type string

-- `lua/ark/autocmd.lua` creates its autocommands as it loads, each in a group of its own.

local M = {}

---Records each autocommand created until the case ends in `autocmds` and its event in `events`, both by group, instead
---of creating it. Creating a group meanwhile returns its name.
---@param t                             __test__.support.Harness
---@param autocmds                      table<string, table>
---@param events                        table<string, string|string[]>
---@return nil
function M.record(t, autocmds, events)
  t:patch_table(vim.api, "nvim_create_augroup", function(name)
    return name
  end)
  t:patch_table(vim.api, "nvim_create_autocmd", function(event, opts)
    autocmds[opts.group] = opts
    events[opts.group] = event
    return 1
  end)
end

---Loads `lua/ark/autocmd.lua` without registering its autocommands, and returns them and their events by group.
---@param t                             __test__.support.Harness
---@return table<string, table> autocmds
---@return table<string, string|string[]> events
function M.load(t)
  local autocmds, events = {}, {} ---@type table<string, table>, table<string, string|string[]>
  M.record(t, autocmds, events)
  assert(loadfile("lua/ark/autocmd.lua"))()
  return autocmds, events
end

return M
