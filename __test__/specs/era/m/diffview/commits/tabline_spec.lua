require("ark.bootstrap").setup()
local t = require("__test__.support.harness").new()
local diffview = require("__test__.support.diffview")
local tabline = require("era.m.diffview.view.commits.tabline")

---The display width of statusline `text`.
---@param text                          string
---@return integer
local function display_width(text)
  return vim.api.nvim_eval_statusline(text, {}).width
end

t:test("layout 3 renders status buttons against the left side-by-side pane", function()
  diffview.repository(t)
  local session = diffview.open_log(t, { layout = 3 })

  local component = tabline.status_component()
  local context = { tabnr = session.tabnr }
  local text = component.render(component.refresh(context), context, 120)

  t.assert_true(text:find(stl.icon.symbols.flag_layout_3 .. "₃", 1, true) ~= nil, "layout button")
  t.assert_true(text:find(stl.icon.symbols.flag_fold .. "³", 1, true) ~= nil, "fold default button")
end)

t:test("the commits pane remains the preferred status width", function()
  diffview.repository(t)
  local session = diffview.open_log(t, { layout = 2 })
  local commits_winnr = assert(session.layout.commits_winnr)
  vim.api.nvim_win_set_width(commits_winnr, 10)

  local component = tabline.status_component()
  local context = { tabnr = session.tabnr }
  local snapshot = component.refresh(context)
  local text = component.render(snapshot, context, 120)

  t.assert_eq(commits_winnr, snapshot.winnr, "preferred pane")
  t.assert_true(text:find(stl.icon.git.Git, 1, true) ~= nil, "commit count remains visible")
  t.assert_true(display_width(text) <= vim.api.nvim_win_get_width(commits_winnr), "status width")
end)

t:run()
