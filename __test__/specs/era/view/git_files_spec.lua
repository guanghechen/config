---@diagnostic disable-next-line: unused-local
local __module_name__ = "__test__.specs.era.view.git_files" ---@type string

require("ark.bootstrap").setup()
local t = require("__test__.support.harness").new("era.view.git_files")
local native = require("__test__.support.result_tree")
local GitFiles = require("era.view.git_files")
local Paths = require("era.view.result_paths")
local support = require("__test__.support.git_files")

---@param tcase                         table
---@return era.view.GitFiles
---@return era.view.GitFiles
---@return yoz.git.StatusData
local function fixture(tcase)
  local staged, unstaged = GitFiles.new("staged", "staged"), GitFiles.new("unstaged", "unstaged")
  tcase:defer(function()
    staged:dispose()
    unstaged:dispose()
  end)
  local snapshot = {
    status_map = {
      ["/git/dir/mixed.lua"] = { relative = "dir/mixed.lua", staged = { M = true }, unstaged = { M = true } },
      ["/git/dir/new.lua"] = { relative = "dir/new.lua", staged = {}, unstaged = { ["?"] = true } },
      ["/git/other.lua"] = { relative = "other.lua", staged = { D = true }, unstaged = {} },
    },
    numstats = {
      staged = {
        ["dir/mixed.lua"] = { insertions = 12, deletions = 3 },
        ["other.lua"] = { insertions = 0, deletions = 5 },
      },
      unstaged = {
        ["dir/mixed.lua"] = { insertions = 4, deletions = 1 },
        ["dir/new.lua"] = { insertions = 7, deletions = 0 },
      },
    },
  }
  staged:apply(staged:prepare("/git", { "/git/dir/mixed.lua", "/git/other.lua" }, snapshot, function() end))
  unstaged:apply(unstaged:prepare("/git", { "/git/dir/mixed.lua", "/git/dir/new.lua" }, snapshot, function() end))
  native.await(staged:render("", false))
  native.await(unstaged:render("", false))
  return staged, unstaged, snapshot
end

---@param tree                          era.view.GitFiles
---@param path                          string
---@return era.view.git_files.IMetadata
---@return era.view.git_files.IColumnWidths
local function metadata(tree, path)
  local frame = tree:frame()
  local fields = frame:node(frame:source():id(Paths.key(path))).fields
  return fields.git, fields.git_columns
end

---@param chunks                        [string, string][]
---@return string
local function text(chunks)
  local strings = {}
  for _, chunk in ipairs(chunks) do
    strings[#strings + 1] = chunk[1]
  end
  return table.concat(strings)
end

t:test("mixed files and directory totals use only their own side's line counts", function()
  local staged, unstaged = fixture(t)
  t.assert_eq(" +12 -3 M ", text(GitFiles.overlay(metadata(staged, "/git/dir/mixed.lua"))))
  t.assert_eq("  +4 -1 M ", text(GitFiles.overlay(metadata(unstaged, "/git/dir/mixed.lua"))))
  t.assert_eq(12, metadata(staged, "/git/dir").insertions)
  t.assert_eq(11, metadata(unstaged, "/git/dir").insertions)
  t.assert_eq("M?", metadata(unstaged, "/git/dir").status)
  t.assert_eq(12, staged.totals.insertions)
  t.assert_eq(8, staged.totals.deletions)
  t.assert_eq(11, unstaged.totals.insertions)
  t.assert_eq(1, unstaged.totals.deletions)
  t.assert_eq(2, staged.totals.count)
  t.assert_eq("m_ft_git_staged", GitFiles.overlay(metadata(staged, "/git/dir/mixed.lua"))[3][2])
  t.assert_eq("m_ft_git_unstaged", GitFiles.overlay(metadata(unstaged, "/git/dir/mixed.lua"))[3][2])
end)

t:test("each pane owns folds and selection independently across metadata refreshes", function()
  local staged, unstaged, snapshot = fixture(t)
  local file, directory = Paths.key("/git/dir/mixed.lua"), Paths.key("/git/dir")
  staged:toggle_select(file, true)
  staged:collapse(directory, "collapse")
  native.await(staged:ready())
  t.assert_nil(staged:retrieve_lnum(file))
  t.assert_true(unstaged:retrieve_lnum(file) ~= nil)
  t.assert_false(unstaged:isselected(file))
  local old = staged:frame()
  local id, records = old:source():id(file), staged.source.records
  snapshot.numstats.staged["dir/mixed.lua"].insertions = 1234
  staged:apply(staged:prepare("/git", { "/git/dir/mixed.lua", "/git/other.lua" }, snapshot, function() end))
  native.await(staged:render("", false))
  t.assert_true(staged.source.records == records)
  t.assert_eq(id, staged:frame():source():id(file))
  t.assert_true(staged:isselected(file))
  t.assert_nil(staged:retrieve_lnum(file))
  t.assert_eq(12, old:node(id).fields.git.insertions)
  t.assert_eq(1234, metadata(staged, "/git/dir/mixed.lua").insertions)
  t.assert_eq(3, old:node(id).fields.git_columns.insertions, "old Frames retain their own column widths")
  t.assert_eq(5, staged:frame():node(id).fields.git_columns.insertions)
end)

t:test("directory and overlapping selections resolve only matching files in the current pane", function()
  local staged, unstaged = fixture(t)
  local directory, file = Paths.key("/git/dir"), Paths.key("/git/dir/mixed.lua")
  local files = unstaged:targets({ directory, file })
  t.assert_eq(2, #files)
  t.assert_eq("dir/mixed.lua", files[1].path)
  native.await(unstaged:render("mixed", false))
  files = unstaged:targets({ directory, file })
  t.assert_eq(1, #files)
  t.assert_eq("dir/mixed.lua", files[1].path)
  t.assert_eq(1, #staged:targets({ directory }))
  local clearing = unstaged:render("", false)
  t.assert_eq(1, #unstaged:targets({ directory }), "a pending filter change cannot widen a displayed action")
  native.await(clearing)
  t.assert_eq(2, #unstaged:targets({ directory }))
  native.await(unstaged:render("+4", false))
  t.assert_eq(0, unstaged:linecount(), "counts are not searchable path text")
end)

t:test("unknown stats remain distinct from an empty text file", function()
  local _, unstaged, snapshot = fixture(t)
  snapshot.numstats.unstaged["dir/new.lua"] = nil
  unstaged:apply(unstaged:prepare("/git", { "/git/dir/mixed.lua", "/git/dir/new.lua" }, snapshot, function() end))
  native.await(unstaged:render("", false))
  t.assert_eq(string.rep(" ", 7) .. "— ? ", text(GitFiles.overlay(metadata(unstaged, "/git/dir/new.lua"))))
  t.assert_eq(1, unstaged.totals.unknown)
  t.assert_eq(4, unstaged.totals.insertions)
  snapshot.numstats.unstaged["dir/new.lua"] = { insertions = 0, deletions = 0 }
  unstaged:apply(unstaged:prepare("/git", { "/git/dir/mixed.lua", "/git/dir/new.lua" }, snapshot, function() end))
  native.await(unstaged:render("", false))
  t.assert_eq(" +0 -0 ? ", text(GitFiles.overlay(metadata(unstaged, "/git/dir/new.lua"))))
end)

t:test("cancelled private preparation leaves the published tree intact", function()
  local staged, _, snapshot = fixture(t)
  local frame, records = staged:frame(), staged.source.records
  local ok = pcall(function()
    staged:prepare("/git", { "/git/other.lua" }, snapshot, function()
      error("cancelled")
    end)
  end)
  t.assert_false(ok)
  t.assert_eq(frame:header().data_revision, staged:frame():header().data_revision)
  t.assert_eq(frame:header().row_count, staged:frame():header().row_count)
  t.assert_true(records == staged.source.records)
end)

t:test("native Git supplies different staged and unstaged counts for a partially staged file", function()
  local root = support.repo(t)
  support.write(root, "dir/mixed.lua", { "one", "two", "three", "staged one", "staged two" })
  support.git(root, { "add", "dir/mixed.lua" })
  support.write(root, "dir/mixed.lua", { "one", "two", "three", "staged one", "staged two", "unstaged" })
  local state = support.widget(t, root)
  state.widget:toggle()
  support.ready(state.widget)
  local staged, unstaged = state.widget.panes.staged.tree, state.widget.panes.unstaged.tree
  t.assert_true(state.widget:isvisible())
  t.assert_eq(2, metadata(staged, root .. "/dir/mixed.lua").insertions)
  t.assert_eq(1, metadata(unstaged, root .. "/dir/mixed.lua").insertions)
  t.assert_eq(0, #state.warnings, vim.inspect(state.warnings))
end)

t:run()
