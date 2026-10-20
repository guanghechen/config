require("ark.bootstrap").setup()
local t = require("__test__.support.harness").new()
local treeview = require("__test__.support.treeview")
local Paths = require("era.view.result_paths")

---@param frecency                      ?table
---@return era.m.picker.FiletreeComposer
local function fixture(frecency)
  local observable = stl.c.Observable.from_value
  local composer = era.m.picker.FiletreeComposer.new({
    name = "cooperative paths",
    title = "cooperative paths",
    permanent = true,
    preview = false,
    frecency = frecency,
    search_pattern = observable(""),
    flag_foldempty = observable(false),
    flag_fuzzy = observable(false),
    flag_regex = observable(false),
    flag_case_sensitive = observable(true),
    flag_selected = observable(false),
    flag_viewtype = observable("tree"),
  })
  t:defer(function()
    if not composer:isdisposed() then
      composer:dispose()
    end
  end)
  return composer
end

---@param count                         integer
---@return string[]
local function paths(count)
  local items = {}
  for index = count, 1, -1 do
    items[#items + 1] = string.format("file%05d.lua", index)
  end
  return items
end

t:test("preparation keeps the live source intact, owns its input and preserves native selection", function()
  local composer = fixture()
  composer:reset_filepaths("/workspace", { "keep.lua" }, false)
  treeview.await(composer.result.draw())
  local tree, source = composer._treeview, composer._filetree
  local keep = Paths.key("/workspace/keep.lua")
  tree:toggle_select(keep, true, false)
  treeview.await(tree:ready())
  local previous = source.records
  local files = paths(10000)
  files[#files + 1] = "keep.lua"
  local prepared = composer:prepare_filepaths("/workspace", files)
  t.assert_false(prepared:is_done(), "a wide path set must yield")
  t.assert_true(source.records == previous)
  t.assert_eq(1, tree:linecount(), "the old published result remains readable")
  files[1] = "caller-mutated.lua"
  treeview.await(prepared)
  t.assert_true(composer._filetree == source, "captured source references remain valid")
  t.assert_true(source:contains(Paths.key("/workspace/file10000.lua")))
  t.assert_false(source:contains(Paths.key("/workspace/caller-mutated.lua")))
  t.assert_eq("/workspace/file00001.lua", source:get(composer._uuids_order:keys()[1]).filepath)
  treeview.await(composer.result.draw())
  t.assert_eq(10001, tree:linecount())
  t.assert_true(tree:isselected(keep))
end)

t:test("frecency preparation reads each score once and keeps deterministic ties", function()
  local scores, calls = {}, 0
  for index = 1, 3000 do
    scores[Paths.key(string.format("/rank/file%05d.lua", index))] = index % 7
  end
  local composer = fixture({
    score = function(_, key)
      calls = calls + 1
      return scores[key]
    end,
  })
  treeview.await(composer:prepare_filepaths("/rank", paths(3000)))
  t.assert_eq(3000, calls)
  local previous_score, previous_path = math.huge, ""
  for _, key in ipairs(composer._uuids_order:keys()) do
    local score, path = scores[key], composer._filetree:get(key).filepath
    t.assert_true(score <= previous_score)
    if score == previous_score then
      t.assert_true(previous_path < path, "equal scores retain source name order")
    end
    previous_score, previous_path = score, path
  end
end)

t:test("the first surface waits for prepared paths and applies the current query before publication", function()
  local composer = fixture()
  composer._search_pattern:next("file00001", { silent = true })
  local initial_root, create = nil, composer._treeview._data.create_state
  t:patch_table(composer._treeview._data, "create_state", function(self, root, ...)
    initial_root = root
    return create(self, root, ...)
  end)
  local pending = composer:prepare_filepaths("/workspace", paths(5000))
  composer.result:create_win(
    { border = "none", number = false, winhighlight = "" },
    { row = 0, col = 0, width = 40, height = 6 }
  )
  treeview.await(pending)
  treeview.await(composer._treeview:ready())
  local frame = composer._treeview:frame()
  t.assert_eq(frame:source():id(Paths.key("/workspace")), initial_root.node)
  t.assert_eq(1, composer._treeview:linecount())
  t.assert_eq("/workspace/file00001.lua", composer._treeview:data(composer._treeview:retrieve_uuid(1)).filepath)
end)

t:test("the attached callback can publish the completed producer", function()
  local composer = fixture()
  local called = false
  composer._on_attached = function()
    t.assert_nil(composer._path_request)
    treeview.await(composer.result.draw())
    called = true
  end
  treeview.await(composer:prepare_filepaths("/callback", { "one.lua" }))
  t.assert_true(called)
  t.assert_eq(1, composer._treeview:linecount())
end)

t:test("a reentrant attached callback keeps the newer preparation as the render dependency", function()
  local composer = fixture()
  local next_request
  composer._on_attached = function(_, cwd)
    if cwd == "/first" then
      next_request = composer:prepare_filepaths("/second", paths(5000))
    end
  end
  treeview.await(composer:prepare_filepaths("/first", { "one.lua" }))
  t.assert_true(next_request ~= nil and composer._path_future == next_request)
  treeview.await(next_request)
  t.assert_true(composer._filetree:contains(Paths.key("/second/file00001.lua")))
end)

for _, operation in ipairs({ "new request", "reset", "attach", "hide", "dispose" }) do
  t:test(operation .. " prevents an older producer from committing", function()
    local composer = fixture()
    composer:reset_filepaths("/old", { "old.lua" }, false)
    local pending = composer:prepare_filepaths("/obsolete", paths(10000))
    t.assert_false(pending:is_done())
    if operation == "new request" then
      treeview.await(composer:prepare_filepaths("/latest", { "new.lua" }))
    elseif operation == "reset" then
      composer:reset_filepaths("/latest", { "new.lua" }, false)
    elseif operation == "attach" then
      composer:attach(Paths.key("/old"))
    elseif operation == "hide" then
      composer:hide()
    else
      composer:dispose()
    end
    t.wait_until(function()
      return pending:is_done()
    end, 5000)
    t.assert_false(pending:is_failed(), pending:get_error())
    t.assert_eq("Superseded", pending:get_result().kind)
    if operation ~= "dispose" then
      t.assert_false(composer._filetree:contains(Paths.key("/obsolete/file00001.lua")))
      local expected = (operation == "new request" or operation == "reset") and "/latest/new.lua" or "/old/old.lua"
      t.assert_true(composer._filetree:contains(Paths.key(expected)))
    end
  end)
end

t:run()
