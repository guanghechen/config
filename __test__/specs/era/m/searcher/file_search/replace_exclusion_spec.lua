local harness = require("__test__.support.harness")
require("ark.bootstrap").setup()

local t = harness.new()
local fs = require("__test__.support.fs")
local picker = require("__test__.support.picker")
local treeview = require("__test__.support.treeview")

---@param files                         table<string, string>
---@return string root
local function workspace(files)
  local root = t:tempdir()
  for name, text in pairs(files) do
    fs.write(vim.fs.joinpath(root, name), text)
  end
  return root
end

---@param root                          string
---@param name                          string
---@return string
local function read(root, name)
  return fs.read(vim.fs.joinpath(root, name))
end

---Searches `root` with replacement on and waits until the result is published.
---@param root                          string
---@param pattern                       string
---@param replacement                   string
---@param regex                         boolean
---@return era.m.searcher.FiletreeComposer
local function search(root, pattern, replacement, regex)
  local search_pattern = picker.observable("")
  local composer = picker.searcher(t, {
    name = "replace-exclusion",
    permanent = false,
    preview = false,
    title = "replace exclusion test",
    flag_limit_matches = false,
    flag_regex = regex,
    flag_replace = true,
    replace_pattern = replacement,
    rootpath = root,
    search_pattern = search_pattern,
  })
  picker.show_result(composer, 80, 20)
  treeview.await(composer._treeview:ready())
  search_pattern:next(pattern)
  t.wait_until(function()
    return composer._file_search._active == nil and composer:__is_search_projection_current__()
  end, 5000, "search did not publish")
  return composer
end

---@param composer                      era.m.searcher.FiletreeComposer
---@param desc                          string
---@return nil
local function run(composer, desc)
  picker.action(composer, desc)()
  treeview.await(composer._treeview:ready())
end

---Runs `desc` on the row of the `index`-th match of `name`, as pressing its key there does.
---@param composer                      era.m.searcher.FiletreeComposer
---@param name                          string
---@param index                         integer
---@param desc                          string
---@return nil
local function run_on_match(composer, name, index, desc)
  local locations = nil ---@type era.m.searcher.view.filetree.ILocationEntry[]|nil
  for _, uuid in ipairs(composer._uuids_order) do
    ---@diagnostic disable-next-line: assign-type-mismatch
    local data = composer._filetree:get(uuid) ---@type era.view.result_paths.IFile|nil
    if data ~= nil and vim.fs.basename(data.filepath) == name then
      locations = composer._treeview:retrieve(uuid).locations
    end
  end
  local location = assert(locations and locations[index], string.format("%s has no match %d", name, index))
  local bufnr = t:buffer()
  treeview.await(composer.result.draw(bufnr))
  composer.result:set_lnum_current(assert(composer._treeview:retrieve_lnum(location.locationuuid)))
  treeview.await(composer._treeview:ready())
  vim.api.nvim_buf_delete(bufnr, { force = true })
  run(composer, desc)
end

t:test("replacing all files leaves the matches removed from the result", function()
  local root = workspace({ ["a.txt"] = "needle 1\nneedle 2\nneedle 3\nneedle 4\n" })
  local composer = search(root, "needle", "pin", false)
  run_on_match(composer, "a.txt", 4, "searcher: mark the node invisible")
  run_on_match(composer, "a.txt", 2, "searcher: mark the node invisible")

  run(composer, "searcher: replace all files")

  t.assert_eq("pin 1\nneedle 2\npin 3\nneedle 4\n", read(root, "a.txt"))
end)

t:test("removed matches stay with anchored groups in LF and CRLF files", function()
  local root = workspace({
    ["a.txt"] = "x = 1;\nx = 2;\nx = 3;\n",
    ["b.txt"] = "x = 4;\r\nx = 5;\r\nx = 6;\r\n",
    ["c.txt"] = "x = 7;\n",
  })
  local composer = search(root, [[x = (\d);$]], "y = $1", true)
  run_on_match(composer, "a.txt", 2, "searcher: mark the node invisible")
  run_on_match(composer, "b.txt", 1, "searcher: mark the node invisible")

  run(composer, "searcher: replace all files")

  t.assert_eq("y = 1\nx = 2;\ny = 3\n", read(root, "a.txt"))
  t.assert_eq("x = 4;\r\ny = 5\r\ny = 6\r\n", read(root, "b.txt"))
  t.assert_eq("y = 7\n", read(root, "c.txt"), "a file with every match left is replaced whole")
end)

t:test("replacing single matches one after another keeps the later ones in place", function()
  local root = workspace({ ["a.txt"] = "x = 1;\nx = 2;\nx = 3;\n" })
  local composer = search(root, [[x = (\d+);]], "y = $1$1", true)

  run_on_match(composer, "a.txt", 1, "search: replace file")
  t.assert_eq("y = 11\nx = 2;\nx = 3;\n", read(root, "a.txt"))
  run_on_match(composer, "a.txt", 2, "search: replace file")

  t.assert_eq("y = 11\nx = 2;\ny = 33\n", read(root, "a.txt"))
end)

---The rows of the matches of `name`, as `lnum:col text`.
---@param composer                      era.m.searcher.FiletreeComposer
---@param name                          string
---@return string[]
local function rows(composer, name)
  local result = {} ---@type string[]
  for _, uuid in ipairs(composer._uuids_order) do
    ---@diagnostic disable-next-line: assign-type-mismatch
    local data = composer._filetree:get(uuid) ---@type era.view.result_paths.IFile|nil
    if data ~= nil and vim.fs.basename(data.filepath) == name then
      for _, location in ipairs(composer._treeview:retrieve(uuid).locations or {}) do
        result[#result + 1] = string.format("%d:%d %s", location.lnum, location.col, location.text)
      end
    end
  end
  return result
end

t:test("replacing a match shows the other matches of its file as a new search would", function()
  local root = workspace({ ["a.txt"] = "abcabcabc\nabc\n" })
  local composer = search(root, "abc", "X", false)

  run_on_match(composer, "a.txt", 2, "search: replace file")
  t.assert_eq("abcXabc\nabc\n", read(root, "a.txt"))
  t.assert_same(rows(search(root, "abc", "X", false), "a.txt"), rows(composer, "a.txt"))
  t.assert_same({ "1:0 abcXXabc", "1:4 abcXabcX", "2:0 abcX" }, rows(composer, "a.txt"))
end)

t:run()
