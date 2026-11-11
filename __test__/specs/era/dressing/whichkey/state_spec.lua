local harness = require("__test__.support.harness")
require("ark.bootstrap").setup()

local t = harness.new()
local Whichkey = era.dressing.whichkey

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
  local bufnr = t:buffer(nil, { current = true })
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
  local bufnr = t:buffer(nil, { current = true })
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

  local next_bufnr = t:buffer(nil, { current = true })
  for _, current_bufnr in ipairs({ bufnr, next_bufnr }) do
    for _, mode in ipairs({ "n", "x" }) do
      local tree = assert(state.buf_trees[current_bufnr][mode])
      t.assert_eq("updated description", assert(Whichkey.tree.find(tree, "gz")).desc, "latest description")
      t.assert_eq("new description", assert(Whichkey.tree.find(tree, "gZ")).desc, "inherited mode")
    end
  end
  t.assert_true(trigger_count(next_bufnr) > 0, "new buffer receives triggers")
end)

t:test("wiping an unlisted buffer releases its keymap tree and triggers", function()
  local state = new_state()
  state.setup()
  state.enable()
  local bufnr = t:buffer(nil, { current = true })
  t.assert_true(state.buf_trees[bufnr] ~= nil, "attached tree")
  local triggers = 0 ---@type integer
  for _, trigger in pairs(Whichkey.input.triggers) do
    if trigger.bufnr == bufnr then
      triggers = triggers + 1
    end
  end
  t.assert_true(triggers > 0, "attached triggers")

  vim.api.nvim_buf_delete(bufnr, { force = true })

  t.assert_nil(state.buf_trees[bufnr], "released tree")
  for _, trigger in pairs(Whichkey.input.triggers) do
    t.assert_true(trigger.bufnr ~= bufnr, "released trigger")
  end
end)

t:test("keys a server maps on attach show once its LspAttach handlers have run", function()
  local state = new_state()
  state.setup()
  state.enable()
  local bufnr = t:buffer(nil, { current = true })
  vim.keymap.set("n", "gq1", function() end, { buffer = bufnr, desc = "server key" })
  t.assert_nil(Whichkey.tree.find(state.buf_trees[bufnr].n, "gq1"), "keys are read when the buffer is entered")

  vim.api.nvim_exec_autocmds("LspAttach", { group = "WhichKey", buffer = bufnr, modeline = false })
  t.wait_until(function()
    return Whichkey.tree.find(state.buf_trees[bufnr].n, "gq1") ~= nil
  end, 5000, "server key")
end)

t:test("global keys a plugin maps when it loads show in the buffers already entered", function()
  local state = new_state()
  state.setup()
  state.enable()
  local other = t:buffer(nil, { current = true })
  local bufnr = t:buffer(nil, { current = true })
  vim.keymap.set("n", "gq2", function() end, { desc = "plugin key" })
  t:defer(function()
    pcall(vim.keymap.del, "n", "gq2")
  end)

  vim.api.nvim_exec_autocmds("User", { group = "WhichKey", pattern = "PluginLoad", modeline = false })
  t.wait_until(function()
    return state.buf_trees[bufnr] ~= nil and Whichkey.tree.find(state.buf_trees[bufnr].n, "gq2") ~= nil
  end, 5000, "plugin key in the current buffer")
  t.assert_nil(state.buf_trees[other], "another buffer reads its keys when entered")
  vim.api.nvim_set_current_buf(other)
  t.assert_true(Whichkey.tree.find(state.buf_trees[other].n, "gq2") ~= nil, "plugin key in another buffer")
end)

t:test(
  "disabling after a plugin loads leaves no triggers in the buffers it refreshed while they were not current",
  function()
    local state = new_state()
    state.setup()
    state.enable()
    local other = t:buffer(nil, { current = true })
    t.assert_true(trigger_count(other) > 0, "triggers once entered")
    local bufnr = t:buffer(nil, { current = true })

    vim.api.nvim_exec_autocmds("User", { group = "WhichKey", pattern = "PluginLoad", modeline = false })
    t.wait_until(function()
      return state.buf_trees[bufnr] ~= nil and state.buf_trees[other] == nil
    end, 5000, "refreshed")
    state.disable()
    t.assert_eq(0, trigger_count(bufnr), "the current buffer")
    t.assert_eq(0, trigger_count(other), "a buffer refreshed while not current")
  end
)

t:run()
