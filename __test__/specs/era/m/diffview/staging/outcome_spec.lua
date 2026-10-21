require("ark.bootstrap").setup()
local t = require("__test__.support.harness").new()
local diffview = require("__test__.support.diffview")
local git = require("__test__.support.git")
local action = require("era.m.diffview.view.workspace.action")

---@param refreshes                     { completed: integer }
---@param count                         integer
---@return nil
local function await_refreshes(refreshes, count)
  t.wait_until(function()
    return refreshes.completed >= count
  end, 10000, "completed refreshes")
end

---@param session                       era.m.diffview.WorkspaceSession
---@return string|nil
local function current(session)
  local entry = session.state:get_current_entry()
  return entry and (entry.stage_type .. ":" .. entry.filepath)
end

---Puts the cursor on `path` in the Changes pane of `stage_type` and previews it.
---@param session                       era.m.diffview.WorkspaceSession
---@param stage_type                    "staged"|"unstaged"
---@param path                          string
---@return nil
local function select(session, stage_type, path)
  session.state:set_current_entry(assert(session.state:find_entry(path, stage_type)))
  diffview.cursor_on(session, stage_type, path)
end

---Captures the errors reported for the rest of the case.
---@return { subject: string, message: string }[]
local function capture_reports()
  local reports = {} ---@type { subject: string, message: string }[]
  t:patch_table(stl.reporter, "error", function(report)
    reports[#reports + 1] = report
  end)
  return reports
end

t:test("staging a file selects the next unstaged file and keeps the focus in Unstaged", function()
  local root = diffview.committed(t, { ["first.lua"] = { "1" }, ["second.lua"] = { "2" } })
  diffview.write(root, "first.lua", { "one" })
  diffview.write(root, "second.lua", { "two" })
  local session = diffview.open_workspace(t)
  local refreshes = diffview.count_refreshes(t, session.state)

  select(session, "unstaged", "first.lua")
  action.stage(session)
  await_refreshes(refreshes, 1)
  t.assert_eq("unstaged:second.lua", current(session), "stage selects the next unstaged entry")
  t.assert_eq(session.layout.changes.unstaged.winnr, vim.api.nvim_get_current_win(), "stage keeps unstaged focus")
end)

t:test("unstaging a file selects the next staged file and keeps the focus in Staged", function()
  local root = diffview.committed(t, { ["first.lua"] = { "1" }, ["second.lua"] = { "2" }, ["third.lua"] = { "3" } })
  diffview.write(root, "first.lua", { "one" })
  diffview.write(root, "second.lua", { "two" })
  diffview.write(root, "third.lua", { "three" })
  git.run(root, { "add", "first.lua", "third.lua" })
  local session = diffview.open_workspace(t)
  local refreshes = diffview.count_refreshes(t, session.state)

  select(session, "staged", "first.lua")
  action.unstage(session)
  await_refreshes(refreshes, 1)
  t.assert_eq("staged:third.lua", current(session), "unstage selects the next staged entry")
  t.assert_eq(session.layout.changes.staged.winnr, vim.api.nvim_get_current_win(), "unstage keeps staged focus")
end)

t:test("staging the last unstaged file follows it to Staged", function()
  local root = diffview.committed(t, { ["second.lua"] = { "2" }, ["third.lua"] = { "3" } })
  diffview.write(root, "second.lua", { "two" })
  diffview.write(root, "third.lua", { "three" })
  git.run(root, { "add", "third.lua" })
  local session = diffview.open_workspace(t)
  local refreshes = diffview.count_refreshes(t, session.state)

  select(session, "unstaged", "second.lua")
  action.stage(session)
  await_refreshes(refreshes, 1)
  t.assert_eq("staged:second.lua", current(session), "last transfer follows the canonical destination entry")
  t.assert_eq(
    session.layout.changes.staged.winnr,
    vim.api.nvim_get_current_win(),
    "empty source moves focus to destination"
  )
end)

t:test("staging the last visible file follows it to Staged when only collapsed directories remain", function()
  local root =
    diffview.committed(t, { ["root.lua"] = { "r" }, ["hidden/inside.lua"] = { "i" }, ["third.lua"] = { "3" } })
  diffview.write(root, "root.lua", { "root" })
  diffview.write(root, "hidden/inside.lua", { "inside" })
  diffview.write(root, "third.lua", { "three" })
  git.run(root, { "add", "third.lua" })
  local session = diffview.open_workspace(t)
  local refreshes = diffview.count_refreshes(t, session.state)
  diffview.cursor_on(session, "unstaged", "hidden")
  action.toggle_collapse(session)
  t.wait_until(function()
    return not pcall(diffview.cursor_on, session, "unstaged", "hidden/inside.lua")
  end, 5000, "hidden/ collapsed")

  select(session, "unstaged", "root.lua")
  action.stage(session)
  await_refreshes(refreshes, 1)
  t.assert_eq("staged:root.lua", current(session), "hidden source entries follow the canonical destination entry")
  t.assert_eq(
    session.layout.changes.staged.winnr,
    vim.api.nvim_get_current_win(),
    "hidden-only source moves focus to destination"
  )
end)

t:test("staging a directory selects the next source file and keeps the focus", function()
  local root = diffview.committed(t, { ["src/a.lua"] = { "a" }, ["remaining.lua"] = { "r" }, ["third.lua"] = { "3" } })
  diffview.write(root, "src/a.lua", { "A" })
  diffview.write(root, "remaining.lua", { "remaining" })
  diffview.write(root, "third.lua", { "three" })
  git.run(root, { "add", "third.lua" })
  local session = diffview.open_workspace(t)
  local refreshes = diffview.count_refreshes(t, session.state)

  session.state:set_current_entry(assert(session.state:find_entry("src/a.lua", "unstaged")))
  diffview.cursor_on(session, "unstaged", "src")
  action.stage(session)
  await_refreshes(refreshes, 1)
  t.assert_eq("unstaged:remaining.lua", current(session), "directory stage selects the next source entry")
  t.assert_eq(
    session.layout.changes.unstaged.winnr,
    vim.api.nvim_get_current_win(),
    "directory stage keeps source focus"
  )
end)

t:test("Git work that completes after the session closes leaves its state alone", function()
  local root = diffview.committed(t, { ["deferred.lua"] = { "d" } })
  diffview.write(root, "deferred.lua", { "deferred" })
  local session = diffview.open_workspace(t)
  local resolve_git = nil ---@type fun(lines: string[], code: integer, stderr: string)|nil
  t:patch_table(stl.git.exec, "exec_async", function(_, _, callback)
    resolve_git = callback
  end)
  vim.api.nvim_set_current_win(session.layout.sbs_right_winnr)
  session.state:set_current_entry(assert(session.state:find_entry("deferred.lua", "unstaged")))
  action.stage(session)
  session:close()

  local reads, writes, refreshes = 0, 0, 0
  for name, count in pairs({
    get_current_entry = function()
      reads = reads + 1
    end,
    set_current_entry = function()
      writes = writes + 1
    end,
    request_refresh = function()
      refreshes = refreshes + 1
    end,
  }) do
    t:patch_table(session.state, name, count)
  end
  assert(resolve_git)({}, 0, "")

  t.assert_eq(0, reads, "disposed callback does not read selection")
  t.assert_eq(0, writes, "disposed callback does not write selection")
  t.assert_eq(0, refreshes, "disposed callback does not request refresh")
end)

t:test("stage and unstage report Git failures without refreshing", function()
  local root = diffview.committed(t, { ["locked.txt"] = { "l" }, ["denied.txt"] = { "d" } })
  diffview.write(root, "locked.txt", { "locked" })
  diffview.write(root, "denied.txt", { "denied" })
  git.run(root, { "add", "denied.txt" })
  local session = diffview.open_workspace(t)
  local refreshes = diffview.count_refreshes(t, session.state)
  local reports = capture_reports()
  diffview.record_git(t, function(args)
    if args[2] == "add" then
      return 128, "fatal: Unable to create '.git/index.lock'\n"
    elseif args[2] == "reset" then
      return 1, ""
    end
  end)

  diffview.cursor_on(session, "unstaged", "locked.txt")
  action.stage(session)
  diffview.cursor_on(session, "staged", "denied.txt")
  action.unstage(session)
  t.wait_until(function()
    return #reports == 2
  end, 10000, "two reports")

  t.assert_eq(0, refreshes.requested, "refresh calls")
  t.assert_eq("stage", reports[1].subject, "stage report subject")
  t.assert_eq(
    "Failed to stage `locked.txt` (exit 128): fatal: Unable to create '.git/index.lock'",
    reports[1].message,
    "stage report message"
  )
  t.assert_eq("unstage", reports[2].subject, "unstage report subject")
  t.assert_eq("Failed to unstage `denied.txt` (exit 1).", reports[2].message, "unstage report message")
end)

t:test("discarding a tracked file restores it and refreshes", function()
  local root = diffview.committed(t, { ["tracked.txt"] = { "base" } })
  diffview.write(root, "tracked.txt", { "changed" })
  local session = diffview.open_workspace(t)
  local calls = diffview.record_git(t)
  local refreshes = diffview.count_refreshes(t, session.state)
  local reports = capture_reports()

  diffview.cursor_on(session, "unstaged", "tracked.txt")
  action.reset(session)
  await_refreshes(refreshes, 1)

  local index = diffview.index_calls(calls)
  t.assert_eq(1, #index, "git calls")
  t.assert_same({ "--literal-pathspecs", "checkout", "--", "tracked.txt" }, index[1].args, "checkout")
  t.assert_eq(root, index[1].opts.cwd, "cwd")
  t.assert_eq("base", vim.fn.readfile(root .. "/tracked.txt")[1], "restored")
  t.assert_eq(1, refreshes.requested, "refresh calls")
  t.assert_eq(0, #reports, "error reports")
end)

t:test("discard reports a tracked failure without refreshing", function()
  local root = diffview.committed(t, { ["conflicted.txt"] = { "base" } })
  diffview.write(root, "conflicted.txt", { "changed" })
  local session = diffview.open_workspace(t)
  local refreshes = diffview.count_refreshes(t, session.state)
  local reports = capture_reports()
  diffview.record_git(t, function(args)
    if args[2] == "checkout" then
      return 128, "fatal: checkout failed\n"
    end
  end)

  diffview.cursor_on(session, "unstaged", "conflicted.txt")
  action.reset(session)
  t.wait_until(function()
    return #reports == 1
  end, 10000, "the report")

  t.assert_eq(0, refreshes.requested, "refresh calls")
  t.assert_eq("discard", reports[1].subject, "tracked report subject")
  t.assert_eq(
    "Failed to discard `conflicted.txt` (exit 128): fatal: checkout failed",
    reports[1].message,
    "tracked report message"
  )
end)

t:run()
