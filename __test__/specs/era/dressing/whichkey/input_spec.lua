local harness = require("__test__.support.harness")
require("ark.bootstrap").setup()

local t = harness.new()
local Tree = assert(loadfile("lua/era/dressing/whichkey/tree.lua"))()
t:patch_table(era.dressing.whichkey, "tree", Tree)
local State = assert(loadfile("lua/era/dressing/whichkey/state.lua"))()
t:patch_table(era.dressing.whichkey, "state", State)
local Input = assert(loadfile("lua/era/dressing/whichkey/input.lua"))()
t:patch_table(era.dressing.whichkey, "input", Input)

---@return integer
local function new_buffer()
  local previous_bufnr = vim.api.nvim_get_current_buf()
  local bufnr = vim.api.nvim_create_buf(false, true)
  t:defer(function()
    State.disable()
    Input.detach(bufnr, "n")
    State.buf_trees[bufnr] = nil
    State.suspended[bufnr .. ":n"] = nil
    if vim.api.nvim_buf_is_valid(previous_bufnr) then
      vim.api.nvim_set_current_buf(previous_bufnr)
    end
    if vim.api.nvim_buf_is_valid(bufnr) then
      vim.api.nvim_buf_delete(bufnr, { force = true })
    end
  end)
  vim.api.nvim_set_current_buf(bufnr)
  return bufnr
end

t:test("suspend, resume and disable preserve a mapping that replaced a trigger", function()
  local bufnr = new_buffer()
  State.enable()
  t.assert_eq("wk-trigger", vim.fn.maparg("z", "n", false, true).desc)
  State.suspend(bufnr, "n")
  t.assert_nil(vim.fn.maparg("z", "n", false, true).desc, "owned trigger is removed")
  State.resume(bufnr, "n")
  t.assert_eq("wk-trigger", vim.fn.maparg("z", "n", false, true).desc, "owned trigger can resume")

  local calls = 0
  ---@return nil
  local callback = function()
    calls = calls + 1
  end
  vim.keymap.set("n", "z", callback, { buffer = bufnr, nowait = true, desc = "Explorer: recursive expansion" })
  State.suspend(bufnr, "n")
  t.assert_eq(callback, vim.fn.maparg("z", "n", false, true).callback, "suspend keeps the replacement")
  State.resume(bufnr, "n")
  t.assert_eq(callback, vim.fn.maparg("z", "n", false, true).callback, "resume keeps the replacement")
  State.disable()
  t.assert_eq(callback, vim.fn.maparg("z", "n", false, true).callback, "disable keeps the replacement")
  vim.api.nvim_feedkeys("z", "xt", false)
  t.assert_eq(1, calls, "the native mapping still executes")
end)

t:test("trigger attachment checks the target buffer instead of the current buffer", function()
  local bufnr = new_buffer()
  ---@return nil
  local callback = function() end
  vim.keymap.set("n", "z", callback, { buffer = bufnr, nowait = true, desc = "Explorer: recursive expansion" })
  new_buffer()
  Input.__bind__(bufnr, "n", "z", "z")
  local mapping = State.__get_keymap__(bufnr, "n", "z")
  t.assert_true(mapping ~= nil and mapping.callback == callback, "the background mapping is preserved")
end)

t:test("attaching reads each mode's mappings once and leaves mapped keys alone", function()
  local bufnr = new_buffer()
  ---@return nil
  local callback = function() end
  vim.keymap.set("n", "z", callback, { buffer = bufnr, nowait = true, desc = "buffer z" })
  for _, lhs in ipairs({ "gX1", "]X1" }) do
    vim.keymap.set("n", lhs, function() end, { desc = "spec prefix" })
    t:defer(function()
      pcall(vim.keymap.del, "n", lhs)
    end)
  end
  State.enable()
  Input.detach(bufnr, "n")

  local reads = {} ---@type table<string, integer>
  for name, mode_arg in pairs({ nvim_get_keymap = 1, nvim_buf_get_keymap = 2 }) do
    local original = vim.api[name]
    t:patch_table(vim.api, name, function(...)
      local key = name .. ":" .. select(mode_arg, ...)
      reads[key] = (reads[key] or 0) + 1
      return original(...)
    end)
  end
  Input.attach(bufnr)

  local bound = {} ---@type table<string, boolean>
  for _, trigger in pairs(Input.triggers) do
    if trigger.bufnr == bufnr and trigger.mode == "n" then
      bound[trigger.trigger_key] = true
    end
  end
  for key, count in pairs(reads) do
    t.assert_eq(1, count, key .. " is read once per attach")
  end
  t.assert_eq(1, reads["nvim_get_keymap:n"], "normal mode mappings are read")
  t.assert_true(bound["g"] and bound["]"], "prefix triggers are bound")
  t.assert_nil(bound["z"], "no trigger over the buffer mapping")
  t.assert_eq(callback, vim.fn.maparg("z", "n", false, true).callback, "the buffer mapping is preserved")
end)

t:test("exact native mapping is resolved after the which-key tree was built", function()
  local bufnr = vim.api.nvim_create_buf(false, true) ---@type integer
  ---@diagnostic disable-next-line: invisible
  t:defer(function()
    State.buf_trees[bufnr] = nil
    if vim.api.nvim_buf_is_valid(bufnr) then
      vim.api.nvim_buf_delete(bufnr, { force = true })
    end
  end)
  State.__load_keymaps__(bufnr, "n")
  local tree = assert(State.buf_trees[bufnr].n)
  Tree.add(tree, { "gs", group = "surround" })
  vim.keymap.set("n", "gs", function() end, {
    buffer = bufnr,
    desc = "diffview: stage",
    nowait = true,
  })

  local node = assert(Tree.find(tree, "gs"))
  local mapping = assert(State.__get_keymap__(bufnr, "n", "gs"))
  t.assert_true(node.is_group, "static group metadata")
  t.assert_eq("diffview: stage", mapping.desc, "late buffer-local mapping")
  t.assert_eq(1, mapping.nowait, "native nowait")
end)

t:test("exact nowait mapping executes without reading a third key", function()
  local reads = 0
  local executed = nil ---@type {node: era.dressing.whichkey.INode|nil, keys: string}|nil
  local bufnr = vim.api.nvim_create_buf(false, true) ---@type integer
  ---@diagnostic disable-next-line: invisible
  t:defer(function()
    if vim.api.nvim_buf_is_valid(bufnr) then
      vim.api.nvim_buf_delete(bufnr, { force = true })
    end
  end)
  vim.keymap.set("n", "gs", function() end, {
    buffer = bufnr,
    desc = "diffview: stage",
    nowait = true,
  })
  local node = {
    key = "s",
    lhs = "gs",
    desc = "diffview: stage",
    is_group = true,
    children = {},
  } ---@type era.dressing.whichkey.INode

  t:patch_table(vim.fn, "getcharstr", function()
    reads = reads + 1
    if reads == 1 then
      return "s"
    end
    error("unexpected third key read")
  end)
  t:patch_table(State, "get_node", function(keys)
    t.assert_eq("gs", keys, "resolved prefix")
    return node
  end)
  t:patch_table(State, "bufnr", bufnr)
  t:patch_table(State, "mode", "n")
  t:patch_table(State, "keys", "")
  t:patch_table(State, "show_popup", false)
  t:patch_table(Input, "__cancel_delay__", function() end)
  t:patch_table(Input, "__is_timedout__", function()
    return false
  end)
  t:patch_table(Input, "__execute__", function(actual_node, keys)
    executed = { node = actual_node, keys = keys }
  end)

  Input.__loop__("g")

  t.assert_eq(1, reads, "input count")
  t.assert_true(executed ~= nil and executed.node == node, "passthrough executed")
  t.assert_eq("gs", executed and executed.keys or nil, "executed keys")
end)

t:test("group-only prefix still waits for a child key", function()
  local reads = 0
  local executed = false
  local stopped = false
  local node = {
    key = "s",
    lhs = "gs",
    desc = "surround",
    is_group = true,
    children = {},
  } ---@type era.dressing.whichkey.INode

  t:patch_table(vim.fn, "getcharstr", function()
    reads = reads + 1
    if reads == 1 then
      return "s"
    end
    error("no child key")
  end)
  t:patch_table(State, "get_node", function()
    return node
  end)
  t:patch_table(State, "__get_keymap__", function()
    return nil
  end)
  t:patch_table(State, "keys", "")
  t:patch_table(State, "show_popup", false)
  t:patch_table(Input, "__cancel_delay__", function() end)
  t:patch_table(Input, "__reschedule_popup__", function() end)
  t:patch_table(Input, "__is_timedout__", function()
    return false
  end)
  t:patch_table(Input, "__execute__", function()
    executed = true
  end)
  t:patch_table(Input, "stop", function()
    stopped = true
  end)

  Input.__loop__("g")

  t.assert_eq(2, reads, "group waits for child")
  t.assert_false(executed, "group is not executed as a mapping")
  t.assert_true(stopped, "input stops after child read fails")
end)

---@param node                          era.dressing.whichkey.INode
---@return { reads: integer, executed: era.dressing.whichkey.INode|false, stopped: boolean }
local function loop_declared(node)
  local result = { reads = 0, executed = false, stopped = false }
  t:patch_table(vim.fn, "getcharstr", function()
    result.reads = result.reads + 1
    if result.reads == 1 then
      return "s"
    end
    error("no further key")
  end)
  t:patch_table(State, "get_node", function()
    return node
  end)
  t:patch_table(State, "__get_keymap__", function()
    error("a declared action does not look up a native mapping")
  end)
  t:patch_table(State, "keys", "")
  t:patch_table(State, "show_popup", false)
  t:patch_table(Input, "__cancel_delay__", function() end)
  t:patch_table(Input, "__reschedule_popup__", function() end)
  t:patch_table(Input, "__is_timedout__", function()
    return false
  end)
  t:patch_table(Input, "__execute__", function(actual_node)
    result.executed = actual_node
  end)
  t:patch_table(Input, "stop", function()
    result.stopped = true
  end)

  Input.__loop__("g")
  return result
end

t:test("a declared action without nowait runs when no longer key starts with it", function()
  local node = { key = "s", lhs = "gs", desc = "surround", action = function() end, children = {} }

  local result = loop_declared(node --[[@as era.dressing.whichkey.INode]])

  t.assert_eq(1, result.reads, "input count")
  t.assert_true(result.executed == node, "declared action executed")
end)

t:test("a declared action without nowait waits for the next key when longer keys start with it", function()
  local child = { key = "a", lhs = "gsa", desc = "add", children = {} }
  local node = { key = "s", lhs = "gs", desc = "surround", action = function() end, children = { a = child } }

  local result = loop_declared(node --[[@as era.dressing.whichkey.INode]])

  t.assert_eq(2, result.reads, "the prefix waits for a child")
  t.assert_false(result.executed, "the action waits for the next key")
  t.assert_true(result.stopped, "input stops after the child read fails")
end)

t:test("a mapping with special keys stays under its own keys, and triggers stay on typed prefixes", function()
  local bufnr = new_buffer()
  for _, lhs in ipairs({ "<C-w>X1", "<C-a>X1" }) do
    vim.keymap.set("n", lhs, function() end, { desc = "special prefix" })
    t:defer(function()
      pcall(vim.keymap.del, "n", lhs)
    end)
  end
  State.enable()

  local tree = assert(State.buf_trees[bufnr].n)
  t.assert_nil(Tree.find(tree, "<lt>"), "no group for a literal <")
  t.assert_true(Tree.find(tree, "<C-W>X1") ~= nil, "the mapping under <C-W>")
  local bound = {} ---@type table<string, true>
  for _, trigger in pairs(Input.triggers) do
    if trigger.bufnr == bufnr then
      bound[trigger.mode .. " " .. trigger.trigger_key] = true
    end
  end
  t.assert_true(bound["n g"] ~= nil, "a typed prefix keeps its trigger")
  for key in pairs(bound) do
    t.assert_true(key:match("^[nx] ") ~= nil, "a trigger outside Normal and Visual mode: " .. key)
  end
  for _, key in ipairs({ "n <lt>", "n <", "n <C-W>", "n <C-A>" }) do
    -- <C-W> and <C-A> run their own commands once 'timeoutlen' passes; a trigger would wait instead.
    t.assert_nil(bound[key], key)
  end
end)

t:test("passed-through keys get no register prefix that 'clipboard' does not name", function()
  local has = vim.fn.has
  t:patch_table(vim.fn, "has", function(feature)
    return feature == "clipboard" and 1 or has(feature)
  end)
  t:patch_table(vim.o, "clipboard", "")
  local fed = {} ---@type string[]
  t:patch_table(vim.api, "nvim_feedkeys", function(keys)
    fed[#fed + 1] = keys
  end)

  Input.__feed_with_context__("<lt>x", "s")
  t.assert_same({ "<x" }, fed, "keys typed over a selection")
end)

t:run()
