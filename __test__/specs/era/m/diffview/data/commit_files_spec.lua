require("ark.bootstrap").setup()
local t = require("__test__.support.harness").new()
local git = require("__test__.support.git")
local data = require("era.m.diffview.data")

---@param root                          string
---@param rev                           string
---@return era.m.diffview.IFileEntry[]
local function files(root, rev)
  local hash = vim.trim(git.run(root, { "rev-parse", rev }))
  return t.await(stl.async.run_future(function()
    return data.fetch_commit_files(hash)
  end))
end

---@param entries                       era.m.diffview.IFileEntry[]
---@return string[]
local function summary(entries)
  local result = {} ---@type string[]
  for _, entry in ipairs(entries) do
    result[#result + 1] =
      string.format("%s %s +%d -%d", entry.status, entry.filepath, entry.insertions, entry.deletions)
  end
  table.sort(result)
  return result
end

t:test("commit files: the root commit lists the files it creates, like any later commit", function()
  local root = git.repo(t)
  vim.fn.writefile({ "one", "two" }, root .. "/a.txt")
  vim.fn.writefile({ "bee" }, root .. "/b.txt")
  git.run(root, { "add", "." })
  git.run(root, { "commit", "-q", "-m", "first" })
  vim.fn.writefile({ "one" }, root .. "/a.txt")
  git.run(root, { "commit", "-q", "-am", "second" })
  t:patch_table(dot.path, "workspace", function()
    return root
  end)

  t.assert_same({ "A a.txt +2 -0", "A b.txt +1 -0" }, summary(files(root, "HEAD~1")), "root commit")
  t.assert_same({ "M a.txt +0 -1" }, summary(files(root, "HEAD")), "later commit")
end)

t:run()
