require("ark.bootstrap").setup()
local t = require("__test__.support.harness").new()
local diffview = require("__test__.support.diffview")
local git = require("__test__.support.git")
local action = require("era.m.diffview.view.workspace.action")

---@param call                          { args: string[], opts: { cwd: string|nil, stdin: string|nil } }
---@param command                       string
---@param root                          string
---@param expected                      string[]
---@return nil
local function assert_transfer_call(call, command, root, expected)
  t.assert_eq("--literal-pathspecs", call.args[1], "literal pathspecs")
  t.assert_eq(command, call.args[2], "git command")
  t.assert_eq("--pathspec-from-file=-", call.args[#call.args - 1], "pathspec stdin")
  t.assert_eq("--pathspec-file-nul", call.args[#call.args], "NUL pathspecs")
  t.assert_eq(root, call.opts.cwd, "cwd")
  t.assert_same(expected, diffview.pathspecs(call), "pathspecs")
end

---@param refreshes                     { completed: integer }
---@param count                         integer
---@return nil
local function await_refreshes(refreshes, count)
  t.wait_until(function()
    return refreshes.completed >= count
  end, 10000, "completed refreshes")
end

t:test("Changes rows stage and unstage the entry at the cursor rather than the previewed one", function()
  local root = diffview.committed(t, { ["a.txt"] = { "a" }, ["b.txt"] = { "b" } })
  diffview.write(root, "a.txt", { "A" })
  diffview.write(root, "b.txt", { "B" })
  diffview.write(root, "c.txt", { "c" })
  git.run(root, { "add", "c.txt" })
  local session = diffview.open_workspace(t)
  local calls = diffview.record_git(t)
  local refreshes = diffview.count_refreshes(t, session.state)

  t.assert_eq("c.txt", session.state:get_current_entry().filepath, "the preview")
  diffview.cursor_on(session, "unstaged", "b.txt")
  action.stage(session)
  await_refreshes(refreshes, 1)

  session.state:set_current_entry(assert(session.state:find_entry("a.txt", "unstaged")))
  diffview.cursor_on(session, "staged", "c.txt")
  action.unstage(session)
  await_refreshes(refreshes, 2)

  local index = diffview.index_calls(calls)
  t.assert_eq(3, #index, "git calls")
  assert_transfer_call(index[1], "add", root, { "b.txt" })
  t.assert_eq("rev-parse", index[2].args[1], "HEAD probe")
  assert_transfer_call(index[3], "reset", root, { "c.txt" })
  t.assert_eq("HEAD", index[3].args[3], "reset target")
  t.assert_eq(2, refreshes.requested, "refresh calls")
end)

t:test("a whole-file stage waits its turn in the repository index queue", function()
  local root = diffview.committed(t, { ["queued.txt"] = { "a" } })
  diffview.write(root, "queued.txt", { "A" })
  local session = diffview.open_workspace(t)
  local calls = diffview.record_git(t)
  local refreshes = diffview.count_refreshes(t, session.state)
  local release = nil ---@type (fun(result: nil): nil)|nil
  era.m.git.index.run(root, function(resolve)
    release = resolve
  end)

  diffview.cursor_on(session, "unstaged", "queued.txt")
  action.stage(session)
  t.assert_eq(0, #diffview.index_calls(calls), "whole-file stage waits")
  assert(release)(nil)
  await_refreshes(refreshes, 1)

  local index = diffview.index_calls(calls)
  t.assert_eq(1, #index, "whole-file stage starts after release")
  assert_transfer_call(index[1], "add", root, { "queued.txt" })
  t.assert_eq(1, refreshes.requested, "refresh after queued stage")
end)

t:test("side-by-side stage and unstage transfer the previewed entry", function()
  local root = diffview.repository(t)
  local session = diffview.open_workspace(t)
  local calls = diffview.record_git(t)
  local refreshes = diffview.count_refreshes(t, session.state)
  vim.api.nvim_set_current_win(session.layout.sbs_right_winnr)

  session.state:set_current_entry(assert(session.state:find_entry("a.txt", "unstaged")))
  action.stage(session)
  await_refreshes(refreshes, 1)
  session.state:set_current_entry(assert(session.state:find_entry("c.txt", "staged")))
  action.unstage(session)
  await_refreshes(refreshes, 2)

  local index = diffview.index_calls(calls)
  t.assert_eq(3, #index, "git calls")
  assert_transfer_call(index[1], "add", root, { "a.txt" })
  t.assert_eq("rev-parse", index[2].args[1], "HEAD probe")
  assert_transfer_call(index[3], "reset", root, { "c.txt" })
  t.assert_eq(2, refreshes.requested, "refresh calls")
end)

t:test("staging a directory sends every unstaged descendant through stdin", function()
  local root = diffview.committed(t, {
    ["legacy.lua"] = { "legacy" },
    ["outside.lua"] = { "outside" },
    ["src/a.lua"] = { "a" },
    ["src/already.lua"] = { "already" },
    ["src/nested/b.lua"] = { "b" },
  })
  for _, path in ipairs({ "outside.lua", "src/a.lua", "src/already.lua", "src/nested/b.lua" }) do
    diffview.write(root, path, { "changed" })
  end
  git.run(root, { "add", "src/already.lua" })
  assert(vim.uv.fs_rename(root .. "/legacy.lua", root .. "/src/new.lua"))
  git.run(root, { "add", "-N", "--", "src/new.lua" })
  local session = diffview.open_workspace(t)
  -- Git never sees the generated paths: the add succeeds without it.
  local calls = diffview.record_git(t, function(args)
    if args[2] == "add" then
      return 0, ""
    end
  end)
  local refreshes = diffview.count_refreshes(t, session.state)

  -- Renames the panel has not rendered still belong to the directory.
  local entries = vim.list_extend({}, session.state:get_entries())
  for i = 1, 20000 do
    entries[#entries + 1] = {
      filepath = string.format("src/generated/%05d.lua", i),
      prev_filepath = string.format("legacy/generated/%05d.lua", i),
      stage_type = "unstaged",
      status = "R",
    }
  end
  local restore = t:patch_table(session.state, "get_entries", function()
    return entries
  end)
  diffview.cursor_on(session, "unstaged", "src")
  action.stage(session)
  restore()
  await_refreshes(refreshes, 1)

  local call = diffview.index_calls(calls)[1]
  t.assert_eq(4, #call.args, "argv stays fixed as external renames grow")
  local pathspecs = diffview.pathspecs(call)
  t.assert_eq(40004, #pathspecs, "all exact snapshot paths")
  local positions = {} ---@type table<string, integer>
  for i, path in ipairs(pathspecs) do
    positions[path] = i
  end
  t.assert_true(positions["src/a.lua"] ~= nil, "direct child")
  t.assert_true(positions["src/nested/b.lua"] ~= nil, "nested child")
  t.assert_eq(positions["src/new.lua"] - 1, positions["legacy.lua"], "rename source before its destination")
  t.assert_eq(
    positions["src/generated/00001.lua"] - 1,
    positions["legacy/generated/00001.lua"],
    "first generated source before its destination"
  )
  t.assert_eq("src/generated/20000.lua", pathspecs[#pathspecs], "last generated destination")
  t.assert_nil(positions["outside.lua"], "outside the directory")
  t.assert_nil(positions["src/already.lua"], "already staged")
  t.assert_eq(1, refreshes.requested, "refresh calls")
end)

t:test("unstaging a directory resets its staged descendants to HEAD", function()
  local root = diffview.committed(t, {
    ["legacy.lua"] = { "legacy" },
    ["outside.lua"] = { "outside" },
    ["src/a.lua"] = { "a" },
  })
  diffview.write(root, "src/a.lua", { "A" })
  diffview.write(root, "outside.lua", { "OUTSIDE" })
  git.run(root, { "add", "src/a.lua", "outside.lua" })
  git.run(root, { "mv", "legacy.lua", "src/new.lua" })
  local session = diffview.open_workspace(t)
  local calls = diffview.record_git(t)
  local refreshes = diffview.count_refreshes(t, session.state)

  diffview.cursor_on(session, "staged", "src")
  action.unstage(session)
  await_refreshes(refreshes, 1)

  local index = diffview.index_calls(calls)
  t.assert_eq("rev-parse", index[1].args[1], "HEAD probe")
  t.assert_eq("reset", index[2].args[2], "git command")
  t.assert_eq("HEAD", index[2].args[3], "reset target")
  local pathspecs = diffview.pathspecs(index[2])
  t.assert_eq(
    "src/new.lua",
    pathspecs[vim.fn.index(pathspecs, "legacy.lua") + 2],
    "rename source before its destination"
  )
  table.sort(pathspecs)
  t.assert_same({ "legacy.lua", "src/a.lua", "src/new.lua" }, pathspecs, "staged descendants and the rename source")
  t.assert_eq(1, refreshes.requested, "HEAD refresh")
end)

t:test("unstaging a directory before the first commit removes its descendants from the index", function()
  local root = diffview.workspace(t, git.repo(t))
  diffview.write(root, "src/new.lua", { "new" })
  diffview.write(root, "outside.lua", { "outside" })
  git.run(root, { "add", "." })
  local session = diffview.open_workspace(t)
  local calls = diffview.record_git(t)
  local refreshes = diffview.count_refreshes(t, session.state)

  diffview.cursor_on(session, "staged", "src")
  action.unstage(session)
  await_refreshes(refreshes, 1)

  local index = diffview.index_calls(calls)
  t.assert_eq("rev-parse", index[1].args[1], "unborn HEAD probe")
  assert_transfer_call(index[2], "rm", root, { "src/new.lua" })
  t.assert_eq("--cached", index[2].args[3], "cached only")
  t.assert_eq("-f", index[2].args[4], "force index removal")
  t.assert_eq(1, refreshes.requested, "unborn refresh")
end)

t:run()
