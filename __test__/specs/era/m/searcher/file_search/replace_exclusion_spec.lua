local harness = require("__test__.support.harness")
require("ark.bootstrap").setup()

local t = harness.new()
local treeview = require("__test__.support.treeview")

---@param value                         unknown
---@return stl.c.Observable
local function observable(value)
  return stl.c.Observable.from_value(value)
end

---@param files                         table<string, string>
---@return string root
local function workspace(files)
  local root = t:tempdir()
  for name, text in pairs(files) do
    local file = assert(io.open(vim.fs.joinpath(root, name), "wb"))
    file:write(text)
    file:close()
  end
  return root
end

---@param root                          string
---@param name                          string
---@return string
local function read(root, name)
  local file = assert(io.open(vim.fs.joinpath(root, name), "rb"))
  local text = file:read("*a")
  file:close()
  return text
end

---Searches `root` with replacement on and waits until the result is published.
---@param root                          string
---@param pattern                       string
---@param replacement                   string
---@param regex                         boolean
---@return era.m.searcher.FiletreeComposer
local function search(root, pattern, replacement, regex)
  local search_pattern = observable("")
  local composer = era.m.searcher.FiletreeComposer.new({
    name = "replace-exclusion",
    permanent = false,
    preview = false,
    title = "replace exclusion test",

    excludes = observable({}),
    flag_exclude = observable(false),
    flag_foldempty = observable(false),
    flag_gitignore = observable(false),
    flag_limit_matches = observable(false),
    flag_regex = observable(regex),
    flag_replace = observable(true),
    flag_case_sensitive = observable(true),
    flag_selected = observable(false),
    flag_viewtype = observable("tree"),
    includes = observable({ "*.txt" }),
    max_filesize = observable("1M"),
    max_matches = observable(500),
    replace_pattern = observable(replacement),
    rootpath = observable(root),
    search_pattern = search_pattern,
  })
  t:defer(function()
    composer:dispose()
  end)
  composer.result:create_win({ border = "none", number = false, winhighlight = "" }, {
    row = 0,
    col = 0,
    width = 80,
    height = 20,
  })
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
  for _, keymap in ipairs(composer.finder.keymaps) do
    if keymap.desc == desc then
      keymap.callback()
      treeview.await(composer._treeview:ready())
      return
    end
  end
  error("no action is bound as " .. desc)
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
  local bufnr = vim.api.nvim_create_buf(false, true)
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

t:run()
