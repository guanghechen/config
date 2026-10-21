require("ark.bootstrap").setup()
local t = require("__test__.support.harness").new()
local CommitsState = require("era.m.diffview.view.commits.state").State
local WorkspaceState = require("era.m.diffview.view.workspace.state").State

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

  state:request_commits_page(3)
  t.assert_eq(3, state:get_commits_page(), "requested page")
  state:reset_commits_page()
  t.assert_eq(1, state:get_commits_page(), "initial applied page")

  state:set_commits_page(2)
  state:request_commits_page(4)
  state:reset_commits_page()
  t.assert_eq(2, state:get_commits_page(), "latest applied page")
  state:dispose()
end)

---@param owner                         era.view.ResultTree
---@param keys                          string[]
---@return nil
local function populate_tree(owner, keys)
  local root = owner.source.root
  owner.entries[root] = { nodetype = "container", foldable = false }
  for _, key in ipairs(keys) do
    owner.source:insert(root, key, { presentation = { label = key } })
    owner.entries[key] = { nodetype = "container" }
  end
  require("__test__.support.treeview").publish(owner)
end

t:test("expanded commits keep directory collapse state independent", function()
  local state = CommitsState.new(101, true)
  t:defer(function()
    state:dispose()
  end)
  local panels = require("era.m.diffview.pane.tree")
  local owner = state:get_tree("commits")
  populate_tree(owner, { panels.key("commit:commit-a", "src", true), panels.key("commit:commit-b", "src", true) })
  state:collapse_commit_dir("commit-a", "src")
  require("__test__.support.treeview").await(owner:ready())
  t.assert_true(state:is_commit_dir_collapsed("commit-a", "src"))
  t.assert_false(state:is_commit_dir_collapsed("commit-b", "src"))
  state:toggle_commit_dir("commit-b", "src")
  state:expand_commit_dir("commit-a", "src")
  require("__test__.support.treeview").await(owner:ready())
  t.assert_false(state:is_commit_dir_collapsed("commit-a", "src"))
  t.assert_true(state:is_commit_dir_collapsed("commit-b", "src"))
end)

t:test("diffview context persists the untracked visibility default", function()
  -- A fresh instance, so the case leaves the runtime's context alone.
  local context = assert(loadfile("lua/dot/context/workspace/diffview.lua"))()

  t.assert_true(context.defaults().flag_untracked, "default visibility")
  t.assert_false(context.normalize({ flag_untracked = false }).flag_untracked, "normalized visibility")
  t.assert_true(context.normalize({ flag_untracked = "invalid" }).flag_untracked, "invalid visibility fallback")

  context.flag_untracked:next(false)
  t.assert_false(context.dump().flag_untracked, "dumped visibility")
  context.load({ flag_untracked = true })
  t.assert_true(context.flag_untracked:snapshot(), "loaded visibility")
end)

t:test("workspace and commits keep independent per-view diff fold policies", function()
  local workspace = WorkspaceState.new(101, false)
  local commits = CommitsState.new(102, true)

  t.assert_false(workspace:get_fold_unchanged(), "workspace expands from its default")
  t.assert_true(commits:get_fold_unchanged(), "commits folds from its default")

  workspace:set_fold_unchanged(true)
  commits:set_fold_unchanged(false)
  t.assert_true(workspace:get_fold_unchanged(), "workspace override")
  t.assert_false(commits:get_fold_unchanged(), "commits override")

  workspace:dispose()
  commits:dispose()
end)

t:test("workspace state disposes its refresh owner and then ignores refreshes", function()
  local disposed = 0
  local uninitialized = WorkspaceState.new(100, true)
  t.assert_false(pcall(uninitialized.request_refresh, uninitialized), "uninitialized refresh still rejected")
  uninitialized:dispose()

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
    populate_tree(state:get_tree(stage), { panels.key(nil, "src", true), panels.key(nil, stage .. "/dir", true) })
  end
  state:collapse_dir("staged", "src")
  require("__test__.support.treeview").await(state:get_tree("staged"):ready())
  t.assert_true(state:is_collapsed("staged", "src"))
  t.assert_false(state:is_collapsed("unstaged", "src"))
  state:toggle_collapse("unstaged", "src")
  state:expand_dir("staged", "src")
  require("__test__.support.treeview").await(state:get_tree("staged"):ready())
  require("__test__.support.treeview").await(state:get_tree("unstaged"):ready())
  t.assert_false(state:is_collapsed("staged", "src"))
  t.assert_true(state:is_collapsed("unstaged", "src"))
  state:collapse_all("staged")
  require("__test__.support.treeview").await(state:get_tree("staged"):ready())
  t.assert_true(state:is_collapsed("staged", "staged/dir"))
  t.assert_false(state:is_collapsed("unstaged", "unstaged/dir"))
end)

t:test("workspace entries snapshot becomes applied only after commit", function()
  local state = WorkspaceState.new(101, true)

  t.assert_false(state:is_entries_snapshot_applied(), "initial empty value is not applied")
  state:set_entries({})
  t.assert_false(state:is_entries_snapshot_applied(), "replaced snapshot remains pending")
  state:commit_entries_snapshot()
  t.assert_true(state:is_entries_snapshot_applied(), "snapshot committed after side effects")
  state:set_entries({})
  t.assert_false(state:is_entries_snapshot_applied(), "later replacement invalidates applied state")
  state:dispose()
end)

t:run()
