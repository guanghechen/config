---@diagnostic disable: undefined-global
--- Run with: nvim -l lua/__test__/era/m/diffview/state.lua

local harness = require("__test__.harness")

local t = harness.new("era.m.diffview.state")

local Observable = {}
Observable.__index = Observable

---@param value                          any
---@return table
function Observable.from_value(value)
  return setmetatable({ value = value, disposed = false }, Observable)
end

---@return any
function Observable:snapshot()
  return self.value
end

---@param value                          any
---@return nil
function Observable:next(value)
  self.value = value
end

---@return nil
function Observable:dispose()
  self.disposed = true
end

---@param path                           string
---@param field                          string
local function verify_invalid_handle_cleanup(path, field)
  local valid = true
  local callback
  local deleted_autocmd

  t:patch_global("stl", { c = { Observable = Observable } })
  t:patch_table(package.loaded, "era.m.diffview.config", { COMMITS_PER_PAGE = 100 })
  t:patch_table(vim.api, "nvim_create_autocmd", function(_, opts)
    callback = opts.callback
    return 77
  end)
  t:patch_table(vim.api, "nvim_del_autocmd", function(autocmd_id)
    deleted_autocmd = autocmd_id
  end)
  t:patch_table(vim.api, "nvim_tabpage_is_valid", function()
    return valid
  end)

  local State = assert(loadfile(path))()
  local state = State.create(101, true)

  callback({ file = "1" })
  local retained_while_valid = State.get(101) == state

  valid = false
  callback({ file = "1" })

  t.assert_true(retained_while_valid, "state retained for valid handle")
  t.assert_nil(State.get(101), "state removed for invalid handle")
  t.assert_true(state[field].disposed, "state observables disposed")
  t.assert_eq(77, deleted_autocmd, "TabClosed autocmd deletion")
end

t:test("workspace state cleanup follows tabpage handle validity", function()
  verify_invalid_handle_cleanup("lua/era/m/diffview/view/workspace/state.lua", "entries")
end)

t:test("commits state cleanup follows tabpage handle validity", function()
  verify_invalid_handle_cleanup("lua/era/m/diffview/view/commits/state.lua", "commits")
end)

t:test("commits content requests use latest-writer ownership and invalidate on dispose", function()
  t:patch_global("stl", { c = { Observable = Observable } })
  t:patch_table(package.loaded, "era.m.diffview.config", { COMMITS_PER_PAGE = 100 })
  local State = assert(loadfile("lua/era/m/diffview/view/commits/state.lua"))()
  local state = State.State.new(101, true)

  local first = state:begin_content_request()
  local second = state:begin_content_request()
  t.assert_false(state:owns_content_request(first), "superseded request")
  t.assert_true(state:owns_content_request(second), "latest request")

  state:dispose()
  t.assert_false(state:owns_content_request(second), "disposed request")
  t.assert_nil(state:begin_content_request(), "disposed state rejects requests")
end)

t:test("commits pagination separates requested and applied pages", function()
  t:patch_global("stl", { c = { Observable = Observable } })
  t:patch_table(package.loaded, "era.m.diffview.config", { COMMITS_PER_PAGE = 100 })
  local State = assert(loadfile("lua/era/m/diffview/view/commits/state.lua"))()
  local state = State.State.new(101, true)

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

t:test("diffview context persists the untracked visibility default", function()
  t:patch_global("stl", { c = { Observable = Observable } })
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
  t:patch_global("stl", { c = { Observable = Observable } })
  t:patch_table(package.loaded, "era.m.diffview.config", { COMMITS_PER_PAGE = 100 })

  local WorkspaceState = assert(loadfile("lua/era/m/diffview/view/workspace/state.lua"))()
  local CommitsState = assert(loadfile("lua/era/m/diffview/view/commits/state.lua"))()
  local workspace = WorkspaceState.State.new(101, false)
  local commits = CommitsState.State.new(102, true)

  t.assert_false(workspace:get_fold_unchanged(), "workspace expands from its default")
  t.assert_true(commits:get_fold_unchanged(), "commits folds from its default")

  workspace:set_fold_unchanged(true)
  commits:set_fold_unchanged(false)
  t.assert_true(workspace:get_fold_unchanged(), "workspace override")
  t.assert_false(commits:get_fold_unchanged(), "commits override")

  workspace:dispose()
  commits:dispose()
end)

t:test("workspace state disposes its refresh owner after unsubscribing", function()
  local disposed = {} ---@type string[]
  local deleted_autocmd = nil ---@type integer|nil
  t:patch_global("stl", { c = { Observable = Observable } })
  t:patch_table(vim.api, "nvim_del_autocmd", function(autocmd_id)
    deleted_autocmd = autocmd_id
  end)
  local State = assert(loadfile("lua/era/m/diffview/view/workspace/state.lua"))()
  local uninitialized = State.State.new(100, true)
  t.assert_false(pcall(uninitialized.request_refresh, uninitialized), "uninitialized refresh still rejected")
  uninitialized:dispose()

  local state = State.State.new(101, true)

  state:set_refresh({
    dispose = function()
      disposed[#disposed + 1] = "refresh"
    end,
  })
  state:set_git_subscription({
    unsubscribe = function()
      disposed[#disposed + 1] = "subscription"
    end,
  })
  state:set_resize_autocmd(88)
  state:dispose()

  t.assert_eq("subscription", disposed[1], "subscription disposed first")
  t.assert_eq("refresh", disposed[2], "refresh owner disposed second")
  t.assert_eq(88, deleted_autocmd, "resize autocmd disposed")
  t.assert_true(state:is_disposed(), "state marked disposed")

  local ok_request = pcall(state.request_refresh, state)
  local ok_check = pcall(state.request_refresh_if_stale, state)
  t.assert_true(ok_request, "late local refresh is ignored")
  t.assert_true(ok_check, "late watcher refresh is ignored")
end)

t:test("workspace keeps staged and unstaged tree state independent", function()
  t:patch_global("stl", { c = { Observable = Observable } })
  local State = assert(loadfile("lua/era/m/diffview/view/workspace/state.lua"))()
  local state = State.State.new(101, true)

  state:collapse_dir("staged", "src")
  t.assert_true(state:is_collapsed("staged", "src"), "staged collapsed")
  t.assert_false(state:is_collapsed("unstaged", "src"), "unstaged remains expanded")

  state:toggle_collapse("unstaged", "src")
  state:expand_dir("staged", "src")
  t.assert_false(state:is_collapsed("staged", "src"), "staged expanded")
  t.assert_true(state:is_collapsed("unstaged", "src"), "unstaged remains collapsed")

  state:set_entries({
    { filepath = "staged/dir/a.lua", stage_type = "staged", status = "M" },
    { filepath = "unstaged/dir/b.lua", stage_type = "unstaged", status = "M" },
  })
  state:collapse_all("staged")
  t.assert_true(state:is_collapsed("staged", "staged/dir"), "staged directories collapsed")
  t.assert_false(state:is_collapsed("unstaged", "unstaged/dir"), "unstaged directories untouched")
  state:dispose()
end)

t:test("workspace entries snapshot becomes applied only after commit", function()
  t:patch_global("stl", { c = { Observable = Observable } })
  local State = assert(loadfile("lua/era/m/diffview/view/workspace/state.lua"))()
  local state = State.State.new(101, true)

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
