require("ark.bootstrap").setup()
local t = require("__test__.support.harness").new()
local diffview = require("__test__.support.diffview")
local commits_view = require("era.m.diffview.view.commits.view")

t:test("hide_commits keeps a commits-only tab alive", function()
  diffview.repository(t)
  local session = diffview.open_log(t, { layout = 4 })
  local lyt = session.layout
  local commits_winnr = assert(lyt.commits_winnr)

  commits_view.hide_commits(lyt)

  t.assert_true(vim.api.nvim_tabpage_is_valid(session.tabnr), "commits-only tab")
  t.assert_true(vim.api.nvim_win_is_valid(commits_winnr), "last window")
  t.assert_eq(commits_winnr, lyt.commits_winnr, "layout reference")
end)

t:test("commit and file panes keep their buffers, and a switch from the commits pane reuses its window", function()
  diffview.repository(t)
  local layout = dot.context.diffview.commits_layout:snapshot()
  t:defer(function()
    dot.context.diffview.commits_layout:next(layout)
  end)
  local session = diffview.open_log(t, { layout = 5 })
  t.assert_true(vim.wo[assert(session.layout.commits_winnr)].winfixbuf, "commits pane")
  t.assert_true(vim.wo[assert(session.layout.filetree_winnr)].winfixbuf, "file pane")

  vim.api.nvim_set_current_win(session.layout.commits_winnr)
  require("era.m.diffview.view.commits.action").switch_to_layout(session, 2)
  local commits_winnr = assert(session.layout.commits_winnr)
  t.assert_eq(2, session.layout.layout_type)
  t.assert_eq(session.layout.commits_bufnr, vim.api.nvim_win_get_buf(commits_winnr), "commits buffer shown")
  t.assert_true(vim.wo[commits_winnr].winfixbuf, "new commits pane")
end)

t:run()
