require("ark.bootstrap").setup()
local t = require("__test__.support.harness").new()
local diffview = require("__test__.support.diffview")
local layout = require("era.m.diffview.layout")

t:test("mouse scroll keeps focus and routes through the hovered window", function()
  local lines = {} ---@type string[]
  for i = 1, 200 do
    lines[i] = string.format("line %03d", i)
  end

  local panel_winnr = vim.api.nvim_get_current_win() ---@type integer
  t:buffer(lines, { current = true })
  local left_winnr, right_winnr = diffview.sbs_windows(t, lines)
  for _, winnr in ipairs({ panel_winnr, left_winnr, right_winnr }) do
    vim.api.nvim_set_option_value("scrolloff", 0, { win = winnr, scope = "local" })
  end
  vim.api.nvim_set_option_value("scrollbind", true, { win = left_winnr, scope = "local" })
  vim.api.nvim_set_option_value("scrollbind", true, { win = right_winnr, scope = "local" })

  local mouse_winnr = right_winnr ---@type integer
  t:patch_table(vim.fn, "getmousepos", function()
    return { winid = mouse_winnr }
  end)
  vim.api.nvim_set_current_win(panel_winnr)
  layout.scroll_mouse("down")

  local left_view = vim.api.nvim_win_call(left_winnr, vim.fn.winsaveview)
  local right_view = vim.api.nvim_win_call(right_winnr, vim.fn.winsaveview)
  t.assert_eq(panel_winnr, vim.api.nvim_get_current_win(), "panel focus")
  t.assert_true(left_view.topline > 1, "left scrolled")
  t.assert_eq(left_view.topline, right_view.topline, "bound windows")

  local down_topline = left_view.topline
  layout.scroll_mouse("up")
  left_view = vim.api.nvim_win_call(left_winnr, vim.fn.winsaveview)
  right_view = vim.api.nvim_win_call(right_winnr, vim.fn.winsaveview)
  t.assert_true(left_view.topline < down_topline, "hovered sbs scrolled up")
  t.assert_eq(left_view.topline, right_view.topline, "bound windows after up")

  mouse_winnr = panel_winnr
  local sbs_topline = left_view.topline
  layout.scroll_mouse("down")

  local panel_view = vim.api.nvim_win_call(panel_winnr, vim.fn.winsaveview)
  left_view = vim.api.nvim_win_call(left_winnr, vim.fn.winsaveview)
  right_view = vim.api.nvim_win_call(right_winnr, vim.fn.winsaveview)
  t.assert_eq(panel_winnr, vim.api.nvim_get_current_win(), "panel focus after panel scroll")
  t.assert_true(panel_view.topline > 1, "hovered panel scrolled")
  t.assert_eq(sbs_topline, left_view.topline, "left sbs unchanged")
  t.assert_eq(sbs_topline, right_view.topline, "right sbs unchanged")

  mouse_winnr = 0
  local panel_topline = panel_view.topline
  layout.scroll_mouse("down")
  panel_view = vim.api.nvim_win_call(panel_winnr, vim.fn.winsaveview)
  t.assert_eq(panel_topline, panel_view.topline, "no window under mouse")
end)

t:run()
