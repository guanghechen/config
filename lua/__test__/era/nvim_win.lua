---@diagnostic disable: undefined-global
--- Run with: nvim -l lua/__test__/era/nvim_win.lua

local bootstrap = require("__test__.bootstrap")
local harness = require("__test__.harness")

local t = harness.new("era.nvim.win")
local enums = require("stl.e")

bootstrap.with_runtime(t, {
  dot = {},
  stl = {
    e = enums,
    env = { IS_TMUX = false },
    reporter = { error = function() end },
  },
})

t:test("Workspace left navigation delegates to Diffview only when handled", function()
  local directions = {} ---@type string[]
  t:patch_table(package.loaded, "era.m.diffview.fn", {
    navigate_window = function(direction)
      directions[#directions + 1] = direction
      return true
    end,
  })

  local win = assert(loadfile("lua/era/nvim/win.lua"))()
  local tabnr = vim.api.nvim_get_current_tabpage() ---@type integer
  vim.t[tabnr].tabtype = enums.TabTypeEnum.DIFFVIEW_WORKSPACE
  win.focus_left()
  win.focus_right()
  t.assert_eq("h", table.concat(directions, ","), "Diffview delegation")

  vim.t[tabnr].tabtype = enums.TabTypeEnum.NORMAL
  win.focus_left()
  t.assert_eq("h", table.concat(directions, ","), "normal navigation bypass")
end)

t:run()
