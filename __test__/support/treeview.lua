---@diagnostic disable-next-line: unused-local
local __module_name__ = "__test__.support.treeview" ---@type string

local harness = require("__test__.support.harness")

local M = {}

---Awaits a native Treeview or Filetree request; a failed request or a Rejected reply raises.
---@param future                        stl.c.Future
---@param timeout_ms                    ?integer
---@return any
function M.await(future, timeout_ms)
  local reply = harness.await(future, timeout_ms)
  if type(reply) == "table" and reply.kind == "Rejected" then
    error("request rejected: " .. vim.inspect(reply), 2)
  end
  return reply
end

---@param future                        stl.c.Future
---@return table
function M.applied(future)
  local reply = harness.await(future)
  if reply.kind ~= "Applied" then
    error("request not applied: " .. vim.inspect(reply), 2)
  end
  return reply
end

---Publishes a ResultTree rooted at its source root unless `options` says otherwise, and returns its frame.
---@param tree                          era.view.ResultTree
---@param options                       ?table
---@return yoz.ux.treeview.Frame
function M.publish(tree, options)
  M.await(tree:publish(vim.tbl_extend("force", { mode = "tree", rootuuid = tree.source.root }, options or {})))
  return assert(tree:frame())
end

---Expansion actions typed ahead: each sequence of open ("o") and collapse ("c") runs back to back, before the
---event loop can publish an earlier action, and must leave `key` as its last action says. `settled` runs after
---each sequence settles.
---@param t                             __test__.support.Harness
---@param tree                          era.view.ResultTree
---@param key                           string
---@param open                          fun()
---@param collapse                      fun()
---@param settled                       ?fun(sequence: string)
---@return nil
function M.assert_typed_ahead(t, tree, key, open, collapse, settled)
  local actions = { o = open, c = collapse } ---@type table<string, fun()>
  for _, sequence in ipairs({ "co", "c", "oc", "oco", "coc" }) do
    for action in sequence:gmatch(".") do
      actions[action]()
    end
    local expanded = sequence:sub(-1) == "o"
    t.wait_until(function()
      return not tree:collapse_pending() and tree:expanded(key) == expanded
    end, 5000, string.format("%s must leave %s %s", sequence, key, expanded and "expanded" or "collapsed"))
    M.await(tree:ready())
    if settled then
      settled(sequence)
    end
  end
end

return M
