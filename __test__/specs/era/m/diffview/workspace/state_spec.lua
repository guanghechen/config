require("ark.bootstrap").setup()
local t = require("__test__.support.harness").new()
local diffview = require("__test__.support.diffview")
local treeview = require("__test__.support.treeview")
local CommitsState = require("era.m.diffview.view.commits.state").State
local WorkspaceState = require("era.m.diffview.view.workspace.state").State

t:test("workspace and commits keep independent per-view diff fold policies", function()
  local workspace = WorkspaceState.new(101, false)
  t:defer(function()
    workspace:dispose()
  end)
  local commits = CommitsState.new(102, true)
  t:defer(function()
    commits:dispose()
  end)

  t.assert_false(workspace:get_fold_unchanged(), "workspace expands from its default")
  t.assert_true(commits:get_fold_unchanged(), "commits folds from its default")

  workspace:set_fold_unchanged(true)
  commits:set_fold_unchanged(false)
  t.assert_true(workspace:get_fold_unchanged(), "workspace override")
  t.assert_false(commits:get_fold_unchanged(), "commits override")
end)

t:test("workspace state disposes its refresh owner and then ignores refreshes", function()
  local disposed = 0
  local uninitialized = WorkspaceState.new(100, true)
  t:defer(function()
    uninitialized:dispose()
  end)
  t.assert_false(pcall(uninitialized.request_refresh, uninitialized), "uninitialized refresh still rejected")

  local state = WorkspaceState.new(101, true)
  state:set_refresh({
    dispose = function()
      disposed = disposed + 1
    end,
  })
  state:dispose()

  t.assert_eq(1, disposed, "refresh owner disposed")
  t.assert_true(state:is_disposed(), "state marked disposed")
  local ok_request = pcall(state.request_refresh, state)
  local ok_check = pcall(state.request_refresh_if_stale, state)
  t.assert_true(ok_request, "late local refresh is ignored")
  t.assert_true(ok_check, "late watcher refresh is ignored")
end)

t:test("workspace keeps staged and unstaged tree state independent", function()
  local state = WorkspaceState.new(101, true)
  t:defer(function()
    state:dispose()
  end)
  local panels = require("era.m.diffview.pane.tree")
  for _, stage in ipairs({ "staged", "unstaged" }) do
    diffview.populate_tree(
      state:get_tree(stage),
      { panels.key(nil, "src", true), panels.key(nil, stage .. "/dir", true) }
    )
  end
  state:collapse_dir("staged", "src")
  treeview.await(state:get_tree("staged"):ready())
  t.assert_true(state:is_collapsed("staged", "src"))
  t.assert_false(state:is_collapsed("unstaged", "src"))
  state:toggle_collapse("unstaged", "src")
  state:expand_dir("staged", "src")
  treeview.await(state:get_tree("staged"):ready())
  treeview.await(state:get_tree("unstaged"):ready())
  t.assert_false(state:is_collapsed("staged", "src"))
  t.assert_true(state:is_collapsed("unstaged", "src"))
  state:collapse_all("staged")
  treeview.await(state:get_tree("staged"):ready())
  t.assert_true(state:is_collapsed("staged", "staged/dir"))
  t.assert_false(state:is_collapsed("unstaged", "unstaged/dir"))
end)

t:test("workspace entries snapshot becomes applied only after commit", function()
  local state = WorkspaceState.new(101, true)
  t:defer(function()
    state:dispose()
  end)

  t.assert_false(state:is_entries_snapshot_applied(), "initial empty value is not applied")
  state:set_entries({})
  t.assert_false(state:is_entries_snapshot_applied(), "replaced snapshot remains pending")
  state:commit_entries_snapshot()
  t.assert_true(state:is_entries_snapshot_applied(), "snapshot committed after side effects")
  state:set_entries({})
  t.assert_false(state:is_entries_snapshot_applied(), "later replacement invalidates applied state")
end)

t:run()
