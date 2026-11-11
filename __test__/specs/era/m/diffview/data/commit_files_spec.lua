require("ark.bootstrap").setup()
local t = require("__test__.support.harness").new()
local diffview = require("__test__.support.diffview")
local fs = require("__test__.support.fs")
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
  local root = diffview.committed(t, { ["a.txt"] = { "one", "two" }, ["b.txt"] = { "bee" } })
  fs.write(root .. "/a.txt", { "one" })
  git.commit(root, "second")

  t.assert_same({ "A a.txt +2 -0", "A b.txt +1 -0" }, summary(files(root, "HEAD~1")), "root commit")
  t.assert_same({ "M a.txt +0 -1" }, summary(files(root, "HEAD")), "later commit")
end)

t:test("commit files: a renamed file is one entry with its previous path and its own counts", function()
  local root = diffview.committed(t, { ["a.txt"] = { "one", "two", "three", "four", "five" }, ["b.txt"] = { "bee" } })
  git.run(root, { "mv", "a.txt", "c.txt" })
  fs.write(root .. "/c.txt", { "one", "TWO", "three", "four", "five" })
  fs.write(root .. "/b.txt", { "BEE" })
  git.commit(root, "rename")

  local entries = files(root, "HEAD")
  t.assert_same({ "M b.txt +1 -1", "R c.txt +1 -1" }, summary(entries))
  for _, entry in ipairs(entries) do
    t.assert_eq(entry.status == "R" and "a.txt" or nil, entry.prev_filepath, entry.filepath)
  end
end)

t:run()
