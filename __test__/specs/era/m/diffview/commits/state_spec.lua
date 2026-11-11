require("ark.bootstrap").setup()
local t = require("__test__.support.harness").new()
local diffview = require("__test__.support.diffview")
local treeview = require("__test__.support.treeview")
local CommitsState = require("era.m.diffview.view.commits.state").State

t:test("commits content requests use latest-writer ownership and invalidate on dispose", function()
  local state = CommitsState.new(101, true)

  local first = state:begin_content_request()
  local second = state:begin_content_request()
  t.assert_false(state:owns_content_request(first), "superseded request")
  t.assert_true(state:owns_content_request(second), "latest request")

  state:dispose()
  t.assert_false(state:owns_content_request(second), "disposed request")
  t.assert_nil(state:begin_content_request(), "disposed state rejects requests")
end)

t:test("commits pagination separates requested and applied pages", function()
  local state = CommitsState.new(101, true)
  t:defer(function()
    state:dispose()
  end)

  state:request_commits_page(3)
  t.assert_eq(3, state:get_commits_page(), "requested page")
  state:reset_commits_page()
  t.assert_eq(1, state:get_commits_page(), "initial applied page")

  state:set_commits_page(2)
  state:request_commits_page(4)
  state:reset_commits_page()
  t.assert_eq(2, state:get_commits_page(), "latest applied page")
end)

t:test("expanded commits keep directory collapse state independent", function()
  local state = CommitsState.new(101, true)
  t:defer(function()
    state:dispose()
  end)
  local panels = require("era.m.diffview.pane.tree")
  local owner = state:get_tree("commits")
  diffview.populate_tree(
    owner,
    { panels.key("commit:commit-a", "src", true), panels.key("commit:commit-b", "src", true) }
  )
  state:collapse_commit_dir("commit-a", "src")
  treeview.await(owner:ready())
  t.assert_true(state:is_commit_dir_collapsed("commit-a", "src"))
  t.assert_false(state:is_commit_dir_collapsed("commit-b", "src"))
  state:toggle_commit_dir("commit-b", "src")
  state:expand_commit_dir("commit-a", "src")
  treeview.await(owner:ready())
  t.assert_false(state:is_commit_dir_collapsed("commit-a", "src"))
  t.assert_true(state:is_commit_dir_collapsed("commit-b", "src"))
end)

t:run()
