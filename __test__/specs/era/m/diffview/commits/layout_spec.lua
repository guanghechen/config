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

t:run()
