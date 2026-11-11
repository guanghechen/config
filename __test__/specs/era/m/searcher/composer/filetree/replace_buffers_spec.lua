local harness = require("__test__.support.harness")
require("ark.bootstrap").setup()

local t = harness.new()
local bootstrap = require("__test__.support.bootstrap")
local fs = require("__test__.support.fs")
local picker = require("__test__.support.picker")
local treeview = require("__test__.support.treeview")

local FILES = picker.REPLACE_FILES
local settle = picker.settle_search
local search = picker.search_needle

---@return string
local function fixture()
  return picker.replace_fixture(t)
end

---@param dir                           string
---@return era.m.searcher.FiletreeComposer
---@return __test__.support.picker.IReplaceControls
local function new_composer(dir)
  return picker.replace_composer(t, dir)
end

-- A buffer loaded with the file.
---@param filepath                      string
---@return integer
local function load(filepath)
  local bufnr = vim.fn.bufadd(filepath) ---@type integer
  vim.fn.bufload(bufnr)
  t:defer(function()
    pcall(vim.api.nvim_buf_delete, bufnr, { force = true })
  end)
  return bufnr
end

-- Changes the lines of a buffer as an edit of its own, which undo takes back apart from a later one.
---@param bufnr                         integer
---@param first                         integer
---@param last                          integer
---@param lines                         string[]
---@return nil
local function edit(bufnr, first, last, lines)
  vim.api.nvim_buf_set_lines(bufnr, first, last, true, lines)
  vim.api.nvim_buf_call(bufnr, function()
    vim.cmd("let &undolevels = &undolevels")
  end)
end

---@param bufnr                         integer
---@return string[]
local function buffer_lines(bufnr)
  return vim.api.nvim_buf_get_lines(bufnr, 0, -1, true)
end

t:test("a file open with unsaved changes is replaced in its buffer, through the lines the changes moved", function()
  local dir = fixture()
  local composer, controls = new_composer(dir)
  local warnings = bootstrap.with_reporter(t).warn
  local alpha = load(dir .. "/alpha.txt")
  edit(alpha, 0, 0, { "a new first line" })

  search(composer, controls, "pin")
  picker.action(composer, "searcher: replace all files")()
  t.assert_same(FILES["alpha.txt"], vim.fn.readfile(dir .. "/alpha.txt"), "the file keeps its text")
  t.assert_same(
    { "a new first line", "pin one", "a pin and a pin", "nothing here" },
    buffer_lines(alpha),
    "the buffer takes the replacement"
  )
  t.assert_true(vim.bo[alpha].modified, "the buffer is left to save")
  t.assert_same({ "pin upper", "pin" }, vim.fn.readfile(dir .. "/beta.txt"), "a file no buffer holds")
  t.assert_same({}, warnings, "every match found")

  vim.api.nvim_buf_call(alpha, function()
    vim.cmd("undo")
  end)
  t.assert_same(
    { "a new first line", "needle one", "a needle and a Needle", "nothing here" },
    buffer_lines(alpha),
    "one undo takes the replacement back, and only it"
  )
end)

t:test("a match the unsaved changes edited is left as it is and told", function()
  local dir = fixture()
  local composer, controls = new_composer(dir)
  local warnings = bootstrap.with_reporter(t).warn
  local alpha = load(dir .. "/alpha.txt")
  edit(alpha, 1, 2, { "a needle and a Needle, edited" })

  search(composer, controls, "pin")
  picker.action(composer, "searcher: replace all files")()
  treeview.await(composer.result.draw())
  t.assert_same(
    { "pin one", "a needle and a Needle, edited", "nothing here" },
    buffer_lines(alpha),
    "the match of the line kept as it was"
  )
  t.assert_eq(1, #warnings, "told once")
  t.assert_true(warnings[1].message:find("Left 2 of 3 matches in", 1, true) ~= nil, warnings[1].message)
  t.assert_eq(2, #composer._treeview:retrieve(composer._uuids_order[1]).locations, "the two left stay listed")
end)

t:test("replacing one match of a file open with unsaved changes replaces it in the buffer", function()
  local dir = fixture()
  local composer, controls = new_composer(dir)
  local tree = composer._treeview
  local alpha = load(dir .. "/alpha.txt")
  edit(alpha, 0, 0, { "a new first line" })

  search(composer, controls, "pin")
  local key = composer._uuids_order[1] ---@type string
  composer.result:set_lnum_current(assert(tree:retrieve_lnum(tree:retrieve(key).locations[2].locationuuid)))
  treeview.await(tree:ready())
  picker.action(composer, "search: replace file")()
  treeview.await(composer.result.draw())
  t.assert_same(
    { "a new first line", "needle one", "a pin and a Needle", "nothing here" },
    buffer_lines(alpha),
    "the second match"
  )
  t.assert_same(FILES["alpha.txt"], vim.fn.readfile(dir .. "/alpha.txt"), "the file keeps its text")
  t.assert_eq(2, #tree:retrieve(key).locations, "the others stay listed")
end)

t:test("a file open without changes shows the replacement at once", function()
  local dir = fixture()
  local composer, controls = new_composer(dir)
  local beta = load(dir .. "/beta.txt")

  search(composer, controls, "pin")
  picker.action(composer, "searcher: replace all files")()
  t.assert_same({ "pin upper", "pin" }, vim.fn.readfile(dir .. "/beta.txt"), "the file")
  t.assert_same({ "pin upper", "pin" }, buffer_lines(beta), "its buffer")
  t.assert_false(vim.bo[beta].modified, "nothing left to save")
end)

t:test("a buffer with CRLF line breaks takes the replacement through them", function()
  local dir = fixture()
  local crlf = dir .. "/crlf.txt"
  fs.write(crlf, "x\r\nneedle\r\ny needle\r\n")
  local composer, controls = new_composer(dir)
  local bufnr = load(crlf)
  t.assert_eq("dos", vim.bo[bufnr].fileformat, "read as CRLF")
  edit(bufnr, 0, 1, { "x, edited" })

  -- Across the line break: "needle\r\ny" in the file.
  controls.flag_regex:next(true)
  controls.replace_pattern:next("<$1>")
  controls.search_pattern:next([[needle\r?\n(\w)]])
  settle(composer, "the search did not publish")
  picker.action(composer, "searcher: replace all files")()
  t.assert_same({ "x, edited", "<y> needle" }, buffer_lines(bufnr), "the line break replaced with the match")
  t.assert_eq("dos", vim.bo[bufnr].fileformat, "still CRLF")
end)

t:test("a match that ends inside a CRLF line break of a buffer is left as it is", function()
  local dir = fixture()
  local crlf = dir .. "/crlf.txt"
  fs.write(crlf, "x\r\nme\r\n")
  local composer, controls = new_composer(dir)
  local warnings = bootstrap.with_reporter(t).warn
  local bufnr = load(crlf)
  edit(bufnr, 0, 1, { "x, edited" })

  controls.flag_regex:next(true)
  controls.replace_pattern:next("!")
  controls.search_pattern:next([[e\r]])
  settle(composer, "the search did not publish")
  picker.action(composer, "searcher: replace all files")()
  t.assert_same({ "x, edited", "me" }, buffer_lines(bufnr), "the rows of the buffer cannot split the line break")
  t.assert_eq(1, #warnings, "told")
end)

t:run()
