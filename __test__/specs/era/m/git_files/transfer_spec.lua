require("ark.bootstrap").setup()
local t = require("__test__.support.harness").new()
local support = require("__test__.support.git_files")
local git = require("__test__.support.git")
local transfer = require("era.m.git_files.transfer")

---@param path                          string
---@param status                        ?string
---@param previous                      ?string
---@return era.view.git_files.IMetadata
local function entry(path, status, previous)
  return { path = path, status = status or "M", previous = previous, scope = "unstaged", count = 1, unknown = 0 }
end

t:test("literal NUL pathspecs stage metacharacters, tabs and newlines without matching siblings", function()
  local root = support.repo(t)
  local paths = { "literal*.lua", ":(glob)star.lua", "tab\tfile.lua", "line\nfile.lua" }
  for _, path in ipairs(paths) do
    support.write(root, path, { "new" })
  end
  support.write(root, "literal-other.lua", { "untouched" })
  local entries = {}
  for _, path in ipairs(paths) do
    entries[#entries + 1] = entry(path, "?")
  end
  t.await(transfer(root, "unstaged", entries))
  local indexed = git.run(root, { "diff", "--cached", "--name-only", "-z" })
  for _, path in ipairs(paths) do
    t.assert_true(indexed:find(path .. "\0", 1, true) ~= nil)
  end
  t.assert_nil(indexed:find("literal-other.lua", 1, true))
  t.await(transfer(root, "staged", entries))
  t.assert_eq("", git.run(root, { "diff", "--cached", "--name-only" }))
  for _, path in ipairs(paths) do
    t.assert_true(vim.uv.fs_stat(root .. "/" .. path) ~= nil)
  end
end)

t:test("unstaging a rename restores both index endpoints and preserves the renamed worktree file", function()
  local root = support.repo(t)
  git.run(root, { "mv", "dir/mixed.lua", "renamed.lua" })
  t.await(transfer(root, "staged", { entry("renamed.lua", "R", "dir/mixed.lua") }))
  t.assert_eq("", git.run(root, { "diff", "--cached", "--name-only" }))
  t.assert_true(vim.uv.fs_stat(root .. "/renamed.lua") ~= nil)
  t.assert_nil(vim.uv.fs_stat(root .. "/dir/mixed.lua"))
  t.assert_true(git.run(root, { "ls-files", "-z" }):find("dir/mixed.lua\0", 1, true) ~= nil)
end)

t:test("copy sources remain staged when only the copied destination is unstaged", function()
  local root = support.repo(t)
  support.write(root, "dir/second.lua", { "base", "changed" })
  support.write(root, "copy.lua", { "base", "changed" })
  git.run(root, { "add", "dir/second.lua", "copy.lua" })
  t.await(transfer(root, "staged", { entry("copy.lua", "C", "dir/second.lua") }))
  t.assert_eq("dir/second.lua\n", git.run(root, { "diff", "--cached", "--name-only" }))
end)

t:test("an unborn repository can stage and unstage without removing worktree files", function()
  local root = support.repo(t, true)
  support.write(root, "new.lua", { "one", "two" })
  t.await(transfer(root, "unstaged", { entry("new.lua", "?") }))
  t.assert_eq("new.lua\n", git.run(root, { "ls-files" }))
  t.await(transfer(root, "staged", { entry("new.lua", "A") }))
  t.assert_eq("", git.run(root, { "ls-files" }))
  t.assert_true(vim.uv.fs_stat(root .. "/new.lua") ~= nil)
end)

t:test("a failed index command leaves the serialization queue usable", function()
  local root = support.repo(t)
  local failed = transfer(root, "unstaged", { entry("missing.lua") })
  t.wait_until(function()
    return failed:is_done()
  end, 5000)
  t.assert_true(failed:is_failed())
  support.write(root, "outside.lua", { "base", "changed" })
  t.await(transfer(root, "unstaged", { entry("outside.lua") }))
  t.assert_eq("outside.lua\n", git.run(root, { "diff", "--cached", "--name-only" }))
end)

t:test("duplicate targets produce one pathspec while writes wait for the existing index queue", function()
  local root = support.repo(t)
  local release
  local holding = era.m.git.index.run(root, function(resolve)
    release = resolve
  end)
  support.write(root, "outside.lua", { "base", "changed" })
  local pending = transfer(root, "unstaged", { entry("outside.lua"), entry("outside.lua") })
  t.assert_false(pending:is_done())
  t.assert_eq("", git.run(root, { "diff", "--cached", "--name-only" }))
  release(true)
  t.await(holding)
  t.await(pending)
  t.assert_eq("outside.lua\n", git.run(root, { "diff", "--cached", "--name-only" }))
end)

t:run()
