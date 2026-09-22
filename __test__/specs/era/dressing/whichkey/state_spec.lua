--- Run with: nvim -l __test__/run.lua __test__/specs/era/dressing/whichkey/state_spec.lua
---@diagnostic disable: undefined-global

local harness = require("__test__.support.harness")
require("ark.bootstrap").setup()

local t = harness.new("era.dressing.whichkey.state")
local Whichkey = era.dressing.whichkey

---@return integer
local function new_buffer()
  local previous_bufnr = vim.api.nvim_get_current_buf() ---@type integer
  local bufnr = vim.api.nvim_create_buf(false, true) ---@type integer
  t:defer(function()
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

---@return era.dressing.whichkey.state
local function new_state()
  local state = assert(loadfile("lua/era/dressing/whichkey/state.lua"))()
  t:patch_table(Whichkey, "state", state)
  t:patch_table(Whichkey, "input", assert(loadfile("lua/era/dressing/whichkey/input.lua"))())
  t:defer(function()
    state.disable()
    pcall(vim.api.nvim_del_augroup_by_name, "WhichKey")
  end)
  return state
end

---@param bufnr                         integer
---@return integer
local function trigger_count(bufnr)
  local count = 0 ---@type integer
  for _, keymap in ipairs(vim.api.nvim_buf_get_keymap(bufnr, "n")) do
    if keymap.desc == "wk-trigger" then
      count = count + 1
    end
  end
  return count
end

t:test("registration before setup survives enabling without polling or binding triggers", function()
  local bufnr = new_buffer()
  local state = new_state()
  local scheduled = 0 ---@type integer
  local restore_schedule = t:patch_table(vim, "schedule", function()
    scheduled = scheduled + 1
  end)

  Whichkey.add({ "gz", desc = "early description" })

  t.assert_eq(0, scheduled, "registration schedules no readiness retry")
  t.assert_eq(0, trigger_count(bufnr), "disabled registration binds no triggers")
  t.assert_false(state.ready, "registration does not enable which-key")
  restore_schedule()

  state.setup()
  state.enable()
  local node = assert(Whichkey.tree.find(state.buf_trees[bufnr].n, "gz"))
  t.assert_eq("early description", node.desc, "early description is available on first enable")
  t.assert_true(trigger_count(bufnr) > 0, "enable attaches native triggers")
end)

t:test("disabled updates survive re-enable and replay in a new buffer", function()
  local bufnr = new_buffer()
  local state = new_state()
  state.setup()
  state.enable()
  Whichkey.add({ "gz", desc = "old description" }, { mode = { "n", "x" } })
  local enabled_triggers = trigger_count(bufnr) ---@type integer
  t.assert_true(enabled_triggers > 0, "enabled triggers")
  state.disable()
  t.assert_eq(0, trigger_count(bufnr), "disable detaches triggers")

  local scheduled = 0 ---@type integer
  local restore_schedule = t:patch_table(vim, "schedule", function()
    scheduled = scheduled + 1
  end)
  Whichkey.add({ "gz", desc = "updated description" }, { mode = { "n", "x" } })
  Whichkey.add({ { mode = { "n", "x" }, { "gZ", desc = "new description" } } })

  t.assert_eq(0, scheduled, "disabled updates schedule no readiness retry")
  t.assert_eq(0, trigger_count(bufnr), "disabled updates bind no triggers")
  restore_schedule()
  state.enable()
  state.enable()
  t.assert_eq(enabled_triggers, trigger_count(bufnr), "re-enable does not duplicate triggers")

  local next_bufnr = new_buffer()
  for _, current_bufnr in ipairs({ bufnr, next_bufnr }) do
    for _, mode in ipairs({ "n", "x" }) do
      local tree = assert(state.buf_trees[current_bufnr][mode])
      t.assert_eq("updated description", assert(Whichkey.tree.find(tree, "gz")).desc, "latest description")
      t.assert_eq("new description", assert(Whichkey.tree.find(tree, "gZ")).desc, "inherited mode")
    end
  end
  t.assert_true(trigger_count(next_bufnr) > 0, "new buffer receives triggers")
end)

t:run()
