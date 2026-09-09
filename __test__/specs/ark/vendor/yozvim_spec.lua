---@diagnostic disable-next-line: unused-local
local __module_name__ = "__test__.specs.ark.vendor.yozvim" ---@type string

local harness = require("__test__.support.harness")
local t = harness.new("ark.vendor.yozvim")

t:test("Yozvim starts its minimal profile without loading IM dressing", function()
  local previous_yozvim = vim.g.yozvim
  vim.g.yozvim = true
  t:defer(function()
    vim.g.yozvim = previous_yozvim
  end)
  t:patch_table(require("dot"), "get_default_storage", function()
    return {}
  end)

  assert(loadfile("init.lua"))()
  t.wait_until(function()
    return package.loaded["era.m.surrounds"] ~= nil and era.dressing.get_load_times().commentstring ~= nil
  end, 3000, "deferred minimal setup did not complete")

  t.assert_true(package.loaded["ark.vendor.yozvim"], "Yozvim entry loaded")
  t.assert_true(package.loaded["era.m.splitjoin"], "splitjoin retained")
  t.assert_true(vim.deep_equal({ "commentstring" }, vim.tbl_keys(era.dressing.get_load_times())))
  t.assert_nil(package.loaded["era.dressing.im"], "IM lifecycle is not loaded")
  t.assert_nil(package.loaded["era.dressing.ui_attach"], "UI remains host-owned")
  t.assert_nil(package.loaded["ark.vendor.yuivim"], "Yuivim entry is not loaded")
  t.assert_nil(vim.g.yuivim, "host identity is unchanged")
end)

t:run()
