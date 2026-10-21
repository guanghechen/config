require("ark.bootstrap").setup()
local t = require("__test__.support.harness").new()
local diffview = require("__test__.support.diffview")
local layout = require("era.m.diffview.layout")

---@param bufnr                         integer
---@param key                           string
---@return boolean
local function has_buffer_keymap(bufnr, key)
  for _, keymap in ipairs(vim.api.nvim_buf_get_keymap(bufnr, "n")) do
    if keymap.lhs == key then
      return true
    end
  end
  return false
end

t:test("mouse scroll keeps focus and routes through the hovered window", function()
  local panel_winnr = vim.api.nvim_get_current_win() ---@type integer
  vim.cmd("belowright split")
  local left_winnr = vim.api.nvim_get_current_win() ---@type integer
  vim.cmd("belowright split")
  local right_winnr = vim.api.nvim_get_current_win() ---@type integer
  local bufnrs = {} ---@type integer[]
  local original_panel_bufnr = vim.api.nvim_win_get_buf(panel_winnr) ---@type integer

  ---@diagnostic disable-next-line: invisible
  t:defer(function()
    for _, winnr in ipairs({ right_winnr, left_winnr }) do
      if vim.api.nvim_win_is_valid(winnr) then
        vim.api.nvim_win_close(winnr, true)
      end
    end
    for _, bufnr in ipairs(bufnrs) do
      if vim.api.nvim_buf_is_valid(bufnr) then
        vim.api.nvim_buf_delete(bufnr, { force = true })
      end
    end
    if vim.api.nvim_win_is_valid(panel_winnr) then
      vim.api.nvim_set_current_win(panel_winnr)
      if vim.api.nvim_buf_is_valid(original_panel_bufnr) then
        vim.api.nvim_win_set_buf(panel_winnr, original_panel_bufnr)
      end
    end
  end)

  local lines = {} ---@type string[]
  for i = 1, 200 do
    lines[i] = string.format("line %03d", i)
  end

  for _, winnr in ipairs({ panel_winnr, left_winnr, right_winnr }) do
    local bufnr = vim.api.nvim_create_buf(false, true) ---@type integer
    bufnrs[#bufnrs + 1] = bufnr
    vim.api.nvim_buf_set_lines(bufnr, 0, -1, false, lines)
    vim.api.nvim_win_set_buf(winnr, bufnr)
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

t:test("commits panes get mouse mappings each time they are created", function()
  diffview.repository(t)
  local session = diffview.open_log(t, { layout = 5 })
  local view = require("era.m.diffview.view.commits.view")
  local lyt = session.layout

  local first_commits_bufnr = assert(lyt.commits_bufnr) ---@type integer
  t.assert_true(has_buffer_keymap(first_commits_bufnr, "<ScrollWheelDown>"), "initial commits mapping")
  view.hide_commits(lyt)
  t.assert_false(vim.api.nvim_buf_is_valid(first_commits_bufnr), "hidden commits buffer wiped")
  view.show_commits(session)
  t.assert_true(has_buffer_keymap(assert(lyt.commits_bufnr), "<ScrollWheelDown>"), "recreated commits mapping")

  local first_filetree_bufnr = assert(lyt.filetree_bufnr) ---@type integer
  t.assert_true(has_buffer_keymap(first_filetree_bufnr, "<ScrollWheelDown>"), "initial filetree mapping")
  view.hide_filetree(lyt)
  t.assert_false(vim.api.nvim_buf_is_valid(first_filetree_bufnr), "hidden filetree buffer wiped")
  view.show_filetree(session)
  t.assert_true(has_buffer_keymap(assert(lyt.filetree_bufnr), "<ScrollWheelDown>"), "recreated filetree mapping")
end)

t:run()
