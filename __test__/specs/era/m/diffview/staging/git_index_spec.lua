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

---@param root                          string
---@return string
local function staged_names(root)
  return git.run(root, { "diff", "--staged", "--name-only", "-z", "--" })
end

t:test("stage, unstage, and discard treat pathspec-magic filenames literally", function()
  local magic = ":(glob)o*.txt" ---@type string
  local root = diffview.committed(t, { [magic] = { "magic base" }, ["other.txt"] = { "other base" } })
  diffview.write(root, magic, { "magic changed" })
  diffview.write(root, "other.txt", { "other changed" })
  local session = diffview.open_workspace(t)
  local refreshes = diffview.count_refreshes(t, session.state)

  diffview.cursor_on(session, "unstaged", magic)
  action.stage(session)
  await_refreshes(refreshes, 1)
  t.assert_eq(magic .. "\0", staged_names(root), "only the literal filename staged")

  diffview.cursor_on(session, "staged", magic)
  action.unstage(session)
  await_refreshes(refreshes, 2)
  t.assert_eq("", staged_names(root), "only the literal filename unstaged")

  diffview.cursor_on(session, "unstaged", magic)
  action.reset(session)
  await_refreshes(refreshes, 3)
  t.assert_eq("magic base", vim.fn.readfile(root .. "/" .. magic)[1], "literal filename discarded")
  t.assert_eq("other changed", vim.fn.readfile(root .. "/other.txt")[1], "glob target preserved")
  t.assert_eq(3, refreshes.requested, "refresh calls")
end)

t:test("staging a rename adds its source and destination, staging the whole rename", function()
  local root = diffview.committed(t, { ["old.lua"] = { "content" } })
  assert(vim.uv.fs_rename(root .. "/old.lua", root .. "/new.lua"))
  git.run(root, { "add", "-N", "--", "new.lua" })
  local session = diffview.open_workspace(t)
  local calls = diffview.record_git(t)
  local refreshes = diffview.count_refreshes(t, session.state)

  diffview.cursor_on(session, "unstaged", "new.lua")
  action.stage(session)
  await_refreshes(refreshes, 1)

  local index = diffview.index_calls(calls)
  t.assert_eq("add", index[1].args[2], "git command")
  t.assert_same({ "old.lua", "new.lua" }, diffview.pathspecs(index[1]), "source and destination")
  local cached = git.run(root, { "diff", "--staged", "--name-status", "--" })
  t.assert_true(cached:find("old.lua", 1, true) ~= nil, "source staged")
  t.assert_true(cached:find("new.lua", 1, true) ~= nil, "destination staged")
  t.assert_eq("", git.run(root, { "diff", "--name-status", "--" }), "rename fully staged")
  t.assert_eq(1, refreshes.requested, "refresh calls")
end)

t:test("unstaging a rename resets its source and destination, leaving no staged residue", function()
  local root = diffview.committed(t, { ["old.lua"] = { "content" } })
  git.run(root, { "mv", "old.lua", "new.lua" })
  local session = diffview.open_workspace(t)
  local calls = diffview.record_git(t)
  local refreshes = diffview.count_refreshes(t, session.state)

  diffview.cursor_on(session, "staged", "new.lua")
  action.unstage(session)
  await_refreshes(refreshes, 1)

  local index = diffview.index_calls(calls)
  t.assert_eq("rev-parse", index[1].args[1], "HEAD probe")
  t.assert_eq("reset", index[2].args[2], "git command")
  t.assert_eq("HEAD", index[2].args[3], "reset target")
  t.assert_same({ "old.lua", "new.lua" }, diffview.pathspecs(index[2]), "source and destination")
  t.assert_eq("", staged_names(root), "index has no staged rename residue")
  t.assert_eq(1, refreshes.requested, "refresh calls")
end)

t:test("unstaging before the first commit removes only the index entry", function()
  local root = diffview.workspace(t, git.repo(t))
  diffview.write(root, "staged.lua", { "content" })
  git.run(root, { "add", "--", "staged.lua" })
  local session = diffview.open_workspace(t)
  local refreshes = diffview.count_refreshes(t, session.state)

  diffview.cursor_on(session, "staged", "staged.lua")
  action.unstage(session)
  await_refreshes(refreshes, 1)

  t.assert_eq(1, git.system(root, { "ls-files", "--error-unmatch", "--", "staged.lua" }).code, "index entry removed")
  t.assert_eq(1, vim.fn.filereadable(root .. "/staged.lua"), "worktree file preserved")
  t.assert_eq(1, refreshes.requested, "refresh calls")
end)

t:run()
