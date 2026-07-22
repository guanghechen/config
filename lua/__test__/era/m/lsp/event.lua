---@diagnostic disable: undefined-global
--- Test for era.m.lsp.event module
--- Run with: nvim -l lua/__test__/era/m/lsp/event.lua

local bootstrap = require("__test__.bootstrap")
local harness = require("__test__.harness")

local t = harness.new("era.m.lsp.event")

bootstrap.with_stl(t, {
  nvim = {
    fn = {
      augroup = function()
        return 1
      end,
    },
  },
})

local blink_loads = 0 ---@type integer
t:patch_table(package.preload, "blink.cmp", function()
  blink_loads = blink_loads + 1
  return {
    get_lsp_capabilities = function()
      return {}
    end,
  }
end)
t:patch_table(package.loaded, "blink.cmp", nil)

local Event = require("era.m.lsp.event")

t:test("capabilities: include completion deltas without loading blink", function()
  local capabilities = Event.get_capabilities()
  Event.before_init({ capabilities = capabilities }, {})

  local completion = capabilities.textDocument.completion
  local completion_item = completion.completionItem
  t.assert_true(vim.list_contains(completion_item.resolveSupport.properties, "detail"), "resolve detail")
  t.assert_true(vim.list_contains(completion_item.resolveSupport.properties, "data"), "resolve data")
  t.assert_eq(1, completion_item.insertTextModeSupport.valueSet[1], "insert text mode support")
  t.assert_true(vim.list_contains(completion.completionList.itemDefaults, "commitCharacters"), "item defaults")
  t.assert_eq(1, completion.insertTextMode, "insert text mode")
  t.assert_true(completion_item.snippetSupport, "snippet support")
  t.assert_eq(0, blink_loads, "blink load count")
end)

t:run()
