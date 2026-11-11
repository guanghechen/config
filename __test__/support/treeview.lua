---@diagnostic disable-next-line: unused-local
local __module_name__ = "__test__.support.treeview" ---@type string

local harness = require("__test__.support.harness")

---@class __test__.support.treeview.IPolls
---@field calls                         integer Polls of the owner since counting began.
---@field demands                       integer Polls that asked to poll again.
---@field sleeping                      boolean Whether the latest poll asked for none.

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

---Data holding `root` with a leaf for each of `labels`, keyed `a`, `b`, `c`, ... in order (by default `a` (alpha) and `b`
---(beta)), and a state over the children of `root`. Returns the ids of the leaves after the data and the state. Requires
---the native library to be loaded.
---@param labels                        ?string[]
---@return ux.treeview.Data data
---@return ux.treeview.State state
---@return string ... ids of the leaves
function M.fixture(labels)
  local records = { { key = "root", label = "root", can_expand = true } }
  for index, label in ipairs(labels or { "alpha", "beta" }) do
    records[index + 1] = { key = string.char(96 + index), parent = "root", label = label }
  end
  local data = require("ux.treeview").new_data()
  M.applied(data:import(records))
  local source = data:source()
  local state = M.await(data:create_state({ kind = "children_of", node = source:id("root") }))
  local ids = {} ---@type string[]
  for index = 2, #records do
    ids[index - 1] = source:id(records[index].key)
  end
  return data, state, unpack(ids)
end

---Attaches a view of `state` with `options`, detached when the case ends.
---@param t                             __test__.support.Harness
---@param state                         ux.treeview.State
---@param options                       ?ux.treeview.IViewOptions
---@return ux.treeview.View
function M.attach(t, state, options)
  local view = require("ux.treeview").attach(state, options)
  t:defer(function()
    view:detach()
  end)
  return view
end

---Counts the polls of `owner`, a Data or another owner that `ux.treeview.async` polls, until the case ends.
---@param t                             __test__.support.Harness
---@param owner                         table
---@return __test__.support.treeview.IPolls
function M.poll_counter(t, owner)
  local polls = { calls = 0, demands = 0, sleeping = false } ---@type __test__.support.treeview.IPolls
  local poll = owner._poll
  t:patch_table(owner, "_poll", function(self)
    polls.calls = polls.calls + 1
    local value = poll(self)
    polls.sleeping = value == nil
    if not polls.sleeping then
      polls.demands = polls.demands + 1
    end
    return value
  end)
  return polls
end

---Waits until `read` returns the same value for `steady_ms`, such as a count of polls once their owner goes idle, and
---returns that value.
---@param read                          fun(): any
---@param steady_ms                     integer
---@param timeout_ms                    integer
---@param msg                           ?string
---@return any
function M.wait_steady(read, steady_ms, timeout_ms, msg)
  local value, since = read(), vim.uv.hrtime()
  harness.wait_until(function()
    local current = read()
    if current ~= value then
      value, since = current, vim.uv.hrtime()
    end
    return vim.uv.hrtime() - since >= steady_ms * 1000000
  end, timeout_ms, msg)
  return value
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
