local harness = require("__test__.support.harness")
require("ark.bootstrap").setup()

local t = harness.new()
local bootstrap = require("__test__.support.bootstrap")
local fs = require("__test__.support.fs")
local picker = require("__test__.support.picker")
local treeview = require("__test__.support.treeview")
local Paths = require("era.view.result_paths")

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

---@param composer                      era.m.searcher.FiletreeComposer
---@return string[]
local function texts(composer)
  local result = {} ---@type string[]
  for _, fileuuid in ipairs(composer._uuids_order) do
    local entry = composer._treeview:retrieve(fileuuid) ---@type era.m.searcher.view.filetree.IEntry|nil
    for _, location in ipairs(entry and entry.locations or {}) do
      result[#result + 1] = location.text
    end
  end
  return result
end

t:test("a refresh brings hidden matches back with the offsets its search finds", function()
  local dir = fixture()
  vim.fn.writefile({ "foo foo foo foo" }, dir .. "/four.txt")
  local composer, controls = new_composer(dir)
  local tree = composer._treeview
  controls.replace_pattern:next("foo foo")
  controls.search_pattern:next("foo")
  settle(composer, "the search did not publish")
  local key = composer._uuids_order[1] ---@type string

  ---@return string[]
  local function offsets()
    local result = {} ---@type string[]
    for _, location in ipairs(tree:retrieve(key).locations) do
      local hidden = tree:isvisible(location.locationuuid) and "" or " hidden"
      result[#result + 1] = location.match.preview.offset .. hidden
    end
    return result
  end

  -- Hide the third match, then replace the first: the text after it moves 4 bytes on.
  local hidden = tree:retrieve(key).locations[3].locationuuid ---@type string
  tree:mark_node_invisible(hidden)
  treeview.await(composer.result.draw())
  composer.result:set_lnum_current(assert(tree:retrieve_lnum(tree:retrieve(key).locations[1].locationuuid)))
  treeview.await(tree:ready())
  picker.action(composer, "search: replace file")()
  treeview.await(composer.result.draw())
  t.assert_same({ "foo foo foo foo foo" }, vim.fn.readfile(dir .. "/four.txt"), "the first match replaced")

  picker.action(composer, "searcher: refresh")()
  treeview.await(composer.result.draw())
  t.assert_false(tree:isvisible(hidden), "the hidden match waits for the search, its offset not moved")
  settle(composer, "the refresh did not publish", function()
    return #tree:retrieve(key).locations == 5
  end)
  t.assert_same({ "0", "4", "8", "12", "16" }, offsets(), "every match back where the search found it")
end)

t:test("replacing all after a single replacement changes only the matches the results list", function()
  local dir = fixture()
  vim.fn.writefile({ "foo foo foo foo" }, dir .. "/four.txt")
  local composer, controls = new_composer(dir)
  local tree = composer._treeview
  controls.replace_pattern:next("foo foo")
  controls.search_pattern:next("foo")
  settle(composer, "the search did not publish")
  local key = composer._uuids_order[1] ---@type string

  -- The replacement of the first match brings in a match at offset 4 that the results do not list.
  composer.result:set_lnum_current(assert(tree:retrieve_lnum(tree:retrieve(key).locations[1].locationuuid)))
  treeview.await(tree:ready())
  picker.action(composer, "search: replace file")()
  treeview.await(composer.result.draw())
  t.assert_same({ "foo foo foo foo foo" }, vim.fn.readfile(dir .. "/four.txt"), "the first match replaced")
  t.assert_eq(3, #tree:retrieve(key).locations, "the three other matches listed")

  picker.action(composer, "searcher: replace all files")()
  -- Five foo kept and three doubled: the one at offset 4 stays as it is.
  t.assert_same({ "foo foo foo foo foo foo foo foo" }, vim.fn.readfile(dir .. "/four.txt"), "the listed matches")
end)

t:test("a pattern that matches bytes outside UTF-8 is searched but tells once that it is not replaced", function()
  local dir = fixture()
  vim.fn.writefile({ "café needle" }, dir .. "/accent.txt")
  local composer, controls = new_composer(dir)
  local warnings = bootstrap.with_reporter(t).warn

  -- The two bytes of "é".
  controls.flag_regex:next(true)
  controls.replace_pattern:next("pin")
  controls.search_pattern:next([[(?-u:\xC3\xA9)]])
  settle(composer, "the search did not publish")
  t.assert_same({ "café needle" }, texts(composer), "the match without a replacement")
  t.assert_eq(1, #warnings, "replace mode tells why")
  t.assert_true(warnings[1].message:find("invalid UTF-8", 1, true) ~= nil, "the reason: " .. warnings[1].message)

  controls.replace_pattern:next("thread")
  settle(composer, "the replacement edit did not publish", function()
    return composer._published_search_inputs.replace_pattern == "thread"
  end)
  t.assert_eq(1, #warnings, "an edit of the replacement does not tell again")

  picker.action(composer, "searcher: replace all files")()
  t.assert_eq(2, #warnings, "replacing all says why it does not")
  t.assert_same({ "café needle" }, vim.fn.readfile(dir .. "/accent.txt"), "the file as it was")

  controls.flag_replace:next(false)
  settle(composer, "leaving replace mode did not publish", function()
    return not composer._published_search_inputs.flag_replace
  end)
  controls.flag_replace:next(true)
  settle(composer, "entering replace mode did not publish", function()
    return composer._published_search_inputs.flag_replace
  end)
  t.assert_eq(3, #warnings, "entering replace mode again tells it again")
end)

t:test("a file that is not UTF-8 text lists the search alone, and replacing all leaves it and says so", function()
  local dir = fixture()
  local latin1 = dir .. "/latin1.txt"
  vim.fn.writefile({ "caf\233 needle" }, latin1)
  local composer, controls = new_composer(dir)
  local errors = bootstrap.with_reporter(t).error

  search(composer, controls, "pin")
  local rows = {} ---@type table<string, string>
  for _, fileuuid in ipairs(composer._uuids_order) do
    local location = composer._treeview:retrieve(fileuuid).locations[1]
    local highlights = location.highlights
    rows[vim.fs.basename(location.match.filepath)] = location.text .. " " .. highlights[#highlights].hlname
  end
  t.assert_eq("needlepin one m_ss_replace", rows["alpha.txt"], "a row with its replacement")
  -- The byte outside UTF-8 shows as U+FFFD.
  t.assert_eq("caf\239\191\189 needle m_ss_matches", rows["latin1.txt"], "the row of the file that is not UTF-8 text")

  picker.action(composer, "searcher: replace all files")()
  t.assert_same({ "pin one", "a pin and a pin", "nothing here" }, vim.fn.readfile(dir .. "/alpha.txt"), "alpha")
  t.assert_same({ "caf\233 needle" }, vim.fn.readfile(latin1), "the file that is not UTF-8 text")
  t.assert_eq(1, #errors, "one report")
  t.assert_eq("not UTF-8 text", errors[1].message, "the reason")
end)

t:test("a file changed after the search is left as it is and told", function()
  local dir = fixture()
  local composer, controls = new_composer(dir)
  local warnings = bootstrap.with_reporter(t).warn
  search(composer, controls, "pin")

  -- Another program deletes the first line: every listed offset of alpha.txt now falls elsewhere.
  vim.fn.writefile({ "a needle and a Needle", "nothing here" }, dir .. "/alpha.txt")
  picker.action(composer, "searcher: replace all files")()
  treeview.await(composer.result.draw())
  t.assert_same({ "a needle and a Needle", "nothing here" }, vim.fn.readfile(dir .. "/alpha.txt"), "alpha as it is")
  t.assert_same({ "pin upper", "pin" }, vim.fn.readfile(dir .. "/beta.txt"), "beta replaced")
  t.assert_eq(1, #warnings, "told once")
  t.assert_true(warnings[1].message:find("alpha.txt changed after the search", 1, true) ~= nil, warnings[1].message)
  t.assert_eq(3, #composer._treeview:retrieve(composer._uuids_order[1]).locations, "its matches stay listed")

  -- A change of the modification time alone tells as well.
  local beta = dir .. "/beta.txt"
  vim.fn.writefile(FILES["beta.txt"], beta)
  settle(composer, "the search did not publish")
  picker.action(composer, "searcher: refresh")()
  settle(composer, "the refresh did not publish", function()
    return #composer._uuids_order == 2
  end)
  local stat = assert(vim.uv.fs_stat(beta))
  assert(vim.uv.fs_utime(beta, stat.atime.sec, stat.mtime.sec + 10))
  picker.action(composer, "searcher: replace all files")()
  t.assert_same(FILES["beta.txt"], vim.fn.readfile(beta), "beta as it is")
  t.assert_eq(2, #warnings, "told again")
end)

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
local function search_root(root, pattern, replacement, regex)
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
  local composer = search_root(root, "needle", "pin", false)
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
  local composer = search_root(root, [[x = (\d);$]], "y = $1", true)
  run_on_match(composer, "a.txt", 2, "searcher: mark the node invisible")
  run_on_match(composer, "b.txt", 1, "searcher: mark the node invisible")

  run(composer, "searcher: replace all files")

  t.assert_eq("y = 1\nx = 2;\ny = 3\n", read(root, "a.txt"))
  t.assert_eq("x = 4;\r\ny = 5\r\ny = 6\r\n", read(root, "b.txt"))
  t.assert_eq("y = 7\n", read(root, "c.txt"), "a file with every match left is replaced whole")
end)

-- Each step replaces the `index`-th match listed for a.txt and leaves the file holding `text`. A step with an `offset`
-- also publishes it for the first match listed after the replacement, while the frame displayed before the first step
-- keeps the offset `displayed` for its second match.
for _, case in ipairs({
  {
    name = "single-match replacements publish updated offsets without mutating the displayed snapshot",
    text = "a a\n",
    pattern = "a",
    replacement = "aaaa",
    regex = false,
    steps = {
      { index = 1, text = "aaaa a\n", offset = 5, displayed = 2 },
      { index = 1, text = "aaaa aaaa\n" },
    },
  },
  {
    name = "replacing single matches one after another keeps the later ones in place",
    text = "x = 1;\nx = 2;\nx = 3;\n",
    pattern = [[x = (\d+);]],
    replacement = "y = $1$1",
    regex = true,
    steps = {
      { index = 1, text = "y = 11\nx = 2;\nx = 3;\n" },
      { index = 2, text = "y = 11\nx = 2;\ny = 33\n" },
    },
  },
}) do
  t:test(case.name, function()
    local root = workspace({ ["a.txt"] = case.text })
    local composer = search_root(root, case.pattern, case.replacement, case.regex)
    local tree = composer._treeview
    local key = Paths.key(vim.fs.joinpath(root, "a.txt"))
    local displayed = tree:retrieve(key)
    for _, step in ipairs(case.steps) do
      run_on_match(composer, "a.txt", step.index, "search: replace file")
      t.assert_eq(step.text, read(root, "a.txt"))
      if step.offset ~= nil then
        t.assert_eq(step.offset, tree:retrieve(key).locations[1].match.preview.offset)
        t.assert_eq(
          step.displayed,
          displayed.locations[2].match.preview.offset,
          "the old frame keeps its original metadata"
        )
      end
    end
  end)
end

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
  local composer = search_root(root, "abc", "X", false)

  run_on_match(composer, "a.txt", 2, "search: replace file")
  t.assert_eq("abcXabc\nabc\n", read(root, "a.txt"))
  t.assert_same(rows(search_root(root, "abc", "X", false), "a.txt"), rows(composer, "a.txt"))
  t.assert_same({ "1:0 abcXXabc", "1:4 abcXabcX", "2:0 abcX" }, rows(composer, "a.txt"))
end)

t:run()
