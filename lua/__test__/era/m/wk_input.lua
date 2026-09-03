---@diagnostic disable: undefined-global
--- Run with: nvim -l lua/__test__/era/m/wk_input.lua

local harness = require("__test__.harness")
require("ark.bootstrap").setup()

local t = harness.new("era.m.wk.input")
local Tree = assert(loadfile("lua/era/m/wk/tree.lua"))()
t:patch_table(era.m.wk, "tree", Tree)
local State = assert(loadfile("lua/era/m/wk/state.lua"))()
t:patch_table(era.m.wk, "state", State)
local Input = assert(loadfile("lua/era/m/wk/input.lua"))()
t:patch_table(era.m.wk, "input", Input)

t:test("exact native mapping is resolved after the which-key tree was built", function()
  local bufnr = vim.api.nvim_create_buf(false, true) ---@type integer
  ---@diagnostic disable-next-line: invisible
  t:_register_cleanup(function()
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
  local executed = nil ---@type {node: era.m.wk.INode|nil, keys: string}|nil
  local bufnr = vim.api.nvim_create_buf(false, true) ---@type integer
  ---@diagnostic disable-next-line: invisible
  t:_register_cleanup(function()
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
  } ---@type era.m.wk.INode

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
  } ---@type era.m.wk.INode

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

t:run()
