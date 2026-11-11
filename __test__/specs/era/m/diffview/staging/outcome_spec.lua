require("ark.bootstrap").setup()
local t = require("__test__.support.harness").new()
local bootstrap = require("__test__.support.bootstrap")
local diffview = require("__test__.support.diffview")
local fs = require("__test__.support.fs")
local git = require("__test__.support.git")
local action = require("era.m.diffview.view.workspace.action")

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
local function select_row(session, stage_type, path)
  session.state:set_current_entry(assert(session.state:find_entry(path, stage_type)))
  diffview.cursor_on(session, stage_type, path)
end

for _, case in ipairs({
  {
    name = "staging a file selects the next unstaged file and keeps the focus in Unstaged",
    committed = { ["first.lua"] = { "1" }, ["second.lua"] = { "2" } },
    edited = { ["first.lua"] = { "one" }, ["second.lua"] = { "two" } },
    staged = {},
    stage_type = "unstaged",
    path = "first.lua",
    transfer = "stage",
    current = "unstaged:second.lua",
    current_label = "stage selects the next unstaged entry",
    focus = "unstaged",
    focus_label = "stage keeps unstaged focus",
  },
  {
    name = "unstaging a file selects the next staged file and keeps the focus in Staged",
    committed = { ["first.lua"] = { "1" }, ["second.lua"] = { "2" }, ["third.lua"] = { "3" } },
    edited = { ["first.lua"] = { "one" }, ["second.lua"] = { "two" }, ["third.lua"] = { "three" } },
    staged = { "first.lua", "third.lua" },
    stage_type = "staged",
    path = "first.lua",
    transfer = "unstage",
    current = "staged:third.lua",
    current_label = "unstage selects the next staged entry",
    focus = "staged",
    focus_label = "unstage keeps staged focus",
  },
  {
    name = "staging the last unstaged file follows it to Staged",
    committed = { ["second.lua"] = { "2" }, ["third.lua"] = { "3" } },
    edited = { ["second.lua"] = { "two" }, ["third.lua"] = { "three" } },
    staged = { "third.lua" },
    stage_type = "unstaged",
    path = "second.lua",
    transfer = "stage",
    current = "staged:second.lua",
    current_label = "last transfer follows the canonical destination entry",
    focus = "staged",
    focus_label = "empty source moves focus to destination",
  },
}) do
  t:test(case.name, function()
    local root = diffview.committed(t, case.committed)
    for path, lines in pairs(case.edited) do
      fs.write(root .. "/" .. path, lines)
    end
    if #case.staged > 0 then
      git.run(root, vim.list_extend({ "add" }, case.staged))
    end
    local session = diffview.open_workspace(t)
    local refreshes = diffview.count_refreshes(t, session.state)

    select_row(session, case.stage_type, case.path)
    action[case.transfer](session)
    diffview.await_refreshes(refreshes, 1)
    t.assert_eq(case.current, current(session), case.current_label)
    t.assert_eq(session.layout.changes[case.focus].winnr, vim.api.nvim_get_current_win(), case.focus_label)
  end)
end

t:test("staging the last visible file follows it to Staged when only collapsed directories remain", function()
  local root =
    diffview.committed(t, { ["root.lua"] = { "r" }, ["hidden/inside.lua"] = { "i" }, ["third.lua"] = { "3" } })
  fs.write(root .. "/root.lua", { "root" })
  fs.write(root .. "/hidden/inside.lua", { "inside" })
  fs.write(root .. "/third.lua", { "three" })
  git.run(root, { "add", "third.lua" })
  local session = diffview.open_workspace(t)
  local refreshes = diffview.count_refreshes(t, session.state)
  diffview.cursor_on(session, "unstaged", "hidden")
  action.toggle_collapse(session)
  t.wait_until(function()
    return diffview.row(session, "unstaged", "hidden/inside.lua") == nil
  end, 5000, "hidden/ collapsed")

  select_row(session, "unstaged", "root.lua")
  action.stage(session)
  diffview.await_refreshes(refreshes, 1)
  t.assert_eq("staged:root.lua", current(session), "hidden source entries follow the canonical destination entry")
  t.assert_eq(
    session.layout.changes.staged.winnr,
    vim.api.nvim_get_current_win(),
    "hidden-only source moves focus to destination"
  )
end)

t:test("staging a directory selects the next source file and keeps the focus", function()
  local root = diffview.committed(t, { ["src/a.lua"] = { "a" }, ["remaining.lua"] = { "r" }, ["third.lua"] = { "3" } })
  fs.write(root .. "/src/a.lua", { "A" })
  fs.write(root .. "/remaining.lua", { "remaining" })
  fs.write(root .. "/third.lua", { "three" })
  git.run(root, { "add", "third.lua" })
  local session = diffview.open_workspace(t)
  local refreshes = diffview.count_refreshes(t, session.state)

  session.state:set_current_entry(assert(session.state:find_entry("src/a.lua", "unstaged")))
  diffview.cursor_on(session, "unstaged", "src")
  action.stage(session)
  diffview.await_refreshes(refreshes, 1)
  t.assert_eq("unstaged:remaining.lua", current(session), "directory stage selects the next source entry")
  t.assert_eq(
    session.layout.changes.unstaged.winnr,
    vim.api.nvim_get_current_win(),
    "directory stage keeps source focus"
  )
end)

t:test("Git work that completes after the session closes leaves its state alone", function()
  local root = diffview.committed(t, { ["deferred.lua"] = { "d" } })
  fs.write(root .. "/deferred.lua", { "deferred" })
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
  fs.write(root .. "/locked.txt", { "locked" })
  fs.write(root .. "/denied.txt", { "denied" })
  git.run(root, { "add", "denied.txt" })
  local session = diffview.open_workspace(t)
  local refreshes = diffview.count_refreshes(t, session.state)
  local reports = bootstrap.with_reporter(t).error
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
  fs.write(root .. "/tracked.txt", { "changed" })
  local session = diffview.open_workspace(t)
  local calls = diffview.record_git(t)
  local refreshes = diffview.count_refreshes(t, session.state)
  local reports = bootstrap.with_reporter(t).error

  diffview.cursor_on(session, "unstaged", "tracked.txt")
  action.reset(session)
  diffview.await_refreshes(refreshes, 1)

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
  fs.write(root .. "/conflicted.txt", { "changed" })
  local session = diffview.open_workspace(t)
  local refreshes = diffview.count_refreshes(t, session.state)
  local reports = bootstrap.with_reporter(t).error
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
