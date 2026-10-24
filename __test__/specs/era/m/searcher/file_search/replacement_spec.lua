local harness = require("__test__.support.harness")
require("ark.bootstrap").setup()

local t = harness.new()
local treeview = require("__test__.support.treeview")

local workspace = t:tempdir()
local case_count = 0

-- Case-insensitive "needle" matches five times: once in the first line, twice in the second and twice in beta.
local FILES = {
  ["alpha.txt"] = { "needle one", "a needle and a Needle", "nothing here" },
  ["beta.txt"] = { "NEEDLE upper", "needle" },
} ---@type table<string, string[]>

---@param value                         unknown
---@return stl.c.Observable
local function observable(value)
  return stl.c.Observable.from_value(value)
end

-- Each case searches its own directory, so a case that writes files leaves the others alone.
---@return string
local function fixture()
  case_count = case_count + 1
  local dir = vim.fs.joinpath(workspace, "case-" .. case_count)
  vim.fn.mkdir(dir, "p")
  for name, lines in pairs(FILES) do
    vim.fn.writefile(lines, vim.fs.joinpath(dir, name))
  end
  return dir
end

---@class __test__.specs.era.m.searcher.file_search.replacement.IControls
---@field public search_pattern         stl.c.Observable
---@field public replace_pattern        stl.c.Observable
---@field public flag_replace           stl.c.Observable

---@class __test__.specs.era.m.searcher.file_search.replacement.ISeen
---@field public searches               integer
---@field public published              era.m.searcher.composer.filetree.ISearchInputs[]

---@param dir                           string
---@return era.m.searcher.FiletreeComposer
---@return __test__.specs.era.m.searcher.file_search.replacement.IControls
local function new_composer(dir)
  local controls = {
    search_pattern = observable(""),
    replace_pattern = observable(""),
    flag_replace = observable(true),
  } ---@type __test__.specs.era.m.searcher.file_search.replacement.IControls
  local composer = era.m.searcher.FiletreeComposer.new({
    name = "replacement-" .. case_count,
    permanent = false,
    preview = false,
    title = "replacement test",

    excludes = observable({}),
    flag_exclude = observable(false),
    flag_foldempty = observable(false),
    flag_gitignore = observable(false),
    flag_limit_matches = observable(true),
    flag_regex = observable(false),
    flag_replace = controls.flag_replace,
    flag_case_sensitive = observable(false),
    flag_selected = observable(false),
    flag_viewtype = observable("tree"),
    includes = observable({ "*.txt" }),
    max_filesize = observable("1M"),
    max_matches = observable(500),
    replace_pattern = controls.replace_pattern,
    rootpath = observable(dir),
    search_pattern = controls.search_pattern,
  })
  t:defer(function()
    composer:dispose()
    vim.wait(20)
  end)
  composer.result:create_win({ border = "none", number = false, winhighlight = "" }, {
    row = 0,
    col = 0,
    width = 80,
    height = 10,
  })
  treeview.await(composer._treeview:ready())
  return composer, controls
end

-- Counts native searches and records the inputs of every publication.
---@param composer                      era.m.searcher.FiletreeComposer
---@return __test__.specs.era.m.searcher.file_search.replacement.ISeen
local function observe(composer)
  local seen = { searches = 0, published = {} } ---@type __test__.specs.era.m.searcher.file_search.replacement.ISeen
  local start = yoz.search.start_search_in_files
  t:patch_table(yoz.search, "start_search_in_files", function(options)
    seen.searches = seen.searches + 1
    return start(options)
  end)
  local apply = composer.__apply_search_result__
  t:patch_table(composer, "__apply_search_result__", function(self, context, result)
    seen.published[#seen.published + 1] = context.inputs
    return apply(self, context, result)
  end)
  return seen
end

-- Waits until no search runs and the published projection reflects the current inputs.
---@param composer                      era.m.searcher.FiletreeComposer
---@param msg                           string
---@param predicate                     ?fun(): boolean
---@param timeout_ms                    ?integer
---@return nil
local function settle(composer, msg, predicate, timeout_ms)
  t.wait_until(function()
    return composer._file_search._active == nil
      and composer:__is_search_projection_current__()
      and (predicate == nil or predicate())
  end, timeout_ms or 5000, msg)
end

-- Outlasts the 64 ms search debounce, so a search the debounce held back would have started.
---@return nil
local function quiet()
  vim.wait(100)
end

-- A debounce far longer than any wait below: a search that starts within one did not wait for it.
---@param composer                      era.m.searcher.FiletreeComposer
---@return nil
local function stretch_debounce(composer)
  t:patch_table(composer._scheduler_search, "_delay", 10000)
end

---@param composer                      era.m.searcher.FiletreeComposer
---@param needle                        string
---@return integer
local function count_texts(composer, needle)
  local count = 0
  for _, fileuuid in ipairs(composer._uuids_order) do
    local entry = composer._treeview:retrieve(fileuuid) ---@type era.m.searcher.view.filetree.IEntry|nil
    for _, location in ipairs(entry and entry.locations or {}) do
      if location.text:find(needle, 1, true) ~= nil then
        count = count + 1
      end
    end
  end
  return count
end

---@param composer                      era.m.searcher.FiletreeComposer
---@param controls                      __test__.specs.era.m.searcher.file_search.replacement.IControls
---@param replacement                   string
---@return nil
local function search(composer, controls, replacement)
  controls.replace_pattern:next(replacement)
  controls.search_pattern:next("needle")
  settle(composer, "the first search did not publish")
end

t:test("a replacement edit searches without waiting for the debounce", function()
  local composer, controls = new_composer(fixture())
  local seen = observe(composer)
  search(composer, controls, "pin")
  t.assert_eq(1, seen.searches, "one search for the query and the replacement set in one turn")
  stretch_debounce(composer)

  controls.replace_pattern:next("thread")
  t.assert_false(composer:__is_search_projection_current__(), "previews of the old replacement are stale at once")
  settle(composer, "the replacement edit waited for the debounce", function()
    return seen.searches == 2
  end, 1000)
  t.assert_eq(5, count_texts(composer, "thread"), "previews of the new replacement")
  t.assert_eq(0, count_texts(composer, "pin"), "no preview keeps the old replacement")
end)

t:test("toggling replace mode searches without waiting for the debounce", function()
  local composer, controls = new_composer(fixture())
  local seen = observe(composer)
  search(composer, controls, "pin")
  stretch_debounce(composer)

  controls.flag_replace:next(false)
  settle(composer, "turning replace mode off waited for the debounce", function()
    return seen.searches == 2
  end, 1000)
  t.assert_eq(0, count_texts(composer, "pin"), "plain previews without replace mode")

  controls.flag_replace:next(true)
  settle(composer, "turning replace mode on waited for the debounce", function()
    return seen.searches == 3
  end, 1000)
  t.assert_eq(5, count_texts(composer, "pin"), "replacement previews in replace mode")
end)

t:test("a query edit still waits for the debounce", function()
  local composer, controls = new_composer(fixture())
  local seen = observe(composer)
  search(composer, controls, "pin")
  stretch_debounce(composer)

  controls.search_pattern:next("a needle")
  vim.wait(300)
  t.assert_eq(1, seen.searches, "the query edit has not searched yet")
  t.assert_false(composer:__is_search_projection_current__(), "the published results are stale until it does")
end)

t:test("a replacement edit together with a query edit searches once with both", function()
  local composer, controls = new_composer(fixture())
  local seen = observe(composer)
  search(composer, controls, "pin")

  -- Query first: its debounced search absorbs the replacement edit of the same turn.
  controls.search_pattern:next("a needle")
  controls.replace_pattern:next("thread")
  settle(composer, "the query edit did not publish", function()
    return composer._published_search_inputs.search_pattern == "a needle"
  end)
  quiet()
  t.assert_eq(2, seen.searches, "one search for a query and a replacement edited in one turn")
  t.assert_eq(2, count_texts(composer, "thread"), "previews of both edits")

  -- Replacement first: its immediate search already reads the query edit of the same turn.
  controls.replace_pattern:next("knot")
  controls.search_pattern:next("needle")
  settle(composer, "the second query edit did not publish", function()
    return composer._published_search_inputs.search_pattern == "needle"
  end)
  quiet()
  t.assert_eq(3, seen.searches, "one search when the replacement edit comes first")
  t.assert_eq(5, count_texts(composer, "knot"), "previews of both edits")

  for _, inputs in ipairs(seen.published) do
    t.assert_false(
      (inputs.search_pattern == "needle" and inputs.replace_pattern == "thread")
        or (inputs.search_pattern == "a needle" and inputs.replace_pattern == "knot"),
      "no publication pairs one query with the replacement edited together with another"
    )
  end
end)

t:test("rapid replacement edits publish the latest replacement last", function()
  local composer, controls = new_composer(fixture())
  local seen = observe(composer)
  search(composer, controls, "pin")

  -- Each edit lands on a turn of its own, as keystrokes do.
  for _, replacement in ipairs({ "t", "th", "thr", "thre", "thread" }) do
    controls.replace_pattern:next(replacement)
    vim.wait(2)
  end
  settle(composer, "the latest edit was not published", function()
    return composer._published_search_inputs.replace_pattern == "thread"
  end)
  quiet()
  t.assert_eq("thread", seen.published[#seen.published].replace_pattern, "no older edit is published after it")
  t.assert_eq(5, count_texts(composer, "thread"), "previews of the latest replacement")
end)

t:test("a replacement edit shows the files as they are on disk", function()
  local dir = fixture()
  local composer, controls = new_composer(dir)
  local seen = observe(composer)
  search(composer, controls, "pin")

  vim.fn.writefile({ "needle one", "a needle and a Needle", "nothing here", "needle again" }, dir .. "/alpha.txt")
  controls.replace_pattern:next("thread")
  settle(composer, "the edit after a file change did not publish", function()
    return seen.searches == 2
  end)
  t.assert_eq(6, count_texts(composer, "thread"), "previews of the changed file")
end)

local test_result = t:run({ exit = false })
vim.fn.delete(workspace, "rf")
os.exit(test_result.failed > 0 and 1 or 0)
