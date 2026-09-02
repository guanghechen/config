---@diagnostic disable: undefined-global
--- Run with: nvim -l lua/__test__/dot/context/session/tab.lua

local bootstrap = require("__test__.bootstrap")
local harness = require("__test__.harness")

local t = harness.new("dot.context.session.tab")
local enums = assert(loadfile("lua/stl/e.lua"))()

bootstrap.with_runtime(t, {
  dot = {
    tab = {
      resolve = function()
        return { bufs = {} }
      end,
    },
  },
  stl = { e = enums },
})

local SessionTab = assert(loadfile("lua/dot/context/session/tab.lua"))()

t:test("session dump excludes transient maximize tabs", function()
  local tabnr_source = vim.api.nvim_get_current_tabpage() ---@type integer
  vim.t[tabnr_source].tabtype = enums.TabTypeEnum.NORMAL
  vim.cmd.tabnew()
  local tabnr_maximize = vim.api.nvim_get_current_tabpage() ---@type integer
  vim.t[tabnr_maximize].tabtype = enums.TabTypeEnum.MAXIMIZE

  local data = SessionTab.dump()

  vim.cmd.tabclose()

  t.assert_eq(1, #data.list, "persisted tab count")
  t.assert_eq(enums.TabTypeEnum.NORMAL, data.list[1].tabtype, "persisted tabtype")
end)

t:run()
