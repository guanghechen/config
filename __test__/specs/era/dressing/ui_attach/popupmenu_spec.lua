--- Run with: nvim -l __test__/run.lua __test__/specs/era/dressing/ui_attach/popupmenu_spec.lua
---@diagnostic disable: undefined-global

local harness = require("__test__.support.harness")

local t = harness.new("era.dressing.ui_attach.popupmenu")

---@return era.dressing.ui_attach.popupmenu
local function setup()
  t:patch_global("dot", {
    var = {
      nsnr = {},
    },
  })
  t:patch_table(vim, "g", { ui_cmdline_pos = { 4, 10 } })

  local states = require("era.dressing.ui_attach.state")
  t:patch_table(states, "cmdline", {
    [1] = {
      level = 1,
      first = "edit ",
      second = "文件",
    },
  })

  ---@diagnostic disable-next-line: redundant-return-value
  return assert(loadfile("lua/era/dressing/ui_attach/popupmenu.lua"))(), states
end

t:test("external cmdline popup applies byte column as display width", function()
  local popupmenu = setup()

  local row, col = popupmenu._resolve_position({
    items = {},
    selected = -1,
    row = 0,
    col = 8,
    grid = -1,
  })

  t.assert_eq(4, row, "popup row")
  t.assert_eq(17, col, "popup column")
end)

t:test("selection scrolls the popup window to the selected item", function()
  local popupmenu, states = setup()
  states.popupmenu = {
    items = { { "a" }, { "b" }, { "c" } },
    selected = -1,
    row = 0,
    col = 0,
    grid = 1,
    bufnr = 1,
    winnr = 2,
  }
  local cursor = nil
  t:patch_table(vim.api, "nvim_buf_is_valid", function()
    return true
  end)
  t:patch_table(vim.api, "nvim_win_is_valid", function()
    return true
  end)
  t:patch_table(vim.api, "nvim_buf_clear_namespace", function() end)
  t:patch_table(vim.api, "nvim_win_set_cursor", function(_, value)
    cursor = value
  end)
  t:patch_table(vim.api, "nvim__redraw", function() end)
  t:patch_table(vim.hl, "range", function() end)

  popupmenu.select({ event = "popupmenu_select", args = { 2 } })

  ---@diagnostic disable-next-line: need-check-nil
  t.assert_eq(3, cursor[1], "selected cursor row")
  ---@diagnostic disable-next-line: need-check-nil
  t.assert_eq(0, cursor[2], "selected cursor column")
end)

t:run()
