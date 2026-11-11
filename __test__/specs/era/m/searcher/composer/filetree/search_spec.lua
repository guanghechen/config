local harness = require("__test__.support.harness")
require("ark.bootstrap").setup()

local t = harness.new()
local bootstrap = require("__test__.support.bootstrap")
local picker = require("__test__.support.picker")
local treeview = require("__test__.support.treeview")

local fixture_dir = t:tempdir()
local fixture_path = vim.fs.joinpath(fixture_dir, "matches.txt")
local fixture_lines = {} ---@type string[]
for index = 1, 5000 do
  fixture_lines[index] = string.format("needle line %04d", index)
end
vim.fn.writefile(fixture_lines, fixture_path)

---@param name                          string
---@param max_matches                   integer
---@return era.m.searcher.FiletreeComposer
---@return table
local function new_composer(name, max_matches)
  local controls = {
    search_pattern = picker.observable(""),
    replace_pattern = picker.observable(""),
    flag_limit_matches = picker.observable(true),
    flag_regex = picker.observable(false),
    flag_replace = picker.observable(false),
    max_matches = picker.observable(max_matches),
  }
  local composer = picker.searcher(t, {
    name = name,
    permanent = false,
    preview = false,
    title = "file-search test",
    flag_limit_matches = controls.flag_limit_matches,
    flag_regex = controls.flag_regex,
    flag_replace = controls.flag_replace,
    max_matches = controls.max_matches,
    replace_pattern = controls.replace_pattern,
    rootpath = fixture_dir,
    search_pattern = controls.search_pattern,
  })
  picker.show_result(composer, 80, 10)
  treeview.await(composer._treeview:ready())
  return composer, controls
end

---Publishes a native search for "needle" over the fixture through a composer and draws it into a scratch buffer;
---the published frame must contain every match.
---@param flag_replace                  boolean
---@param max_matches                   integer
---@return nil
local function assert_publishes_every_match(flag_replace, max_matches)
  local composer, controls =
    new_composer(string.format("publication-%s-%d", tostring(flag_replace), max_matches), max_matches)
  controls.search_pattern:next("needle", { silent = true })
  controls.replace_pattern:next("replacement", { silent = true })
  controls.flag_replace:next(flag_replace, { silent = true })
  controls.max_matches:next(max_matches, { silent = true })

  local request, snapshot_err = composer:__snapshot_search_request__()
  assert(request ~= nil, snapshot_err)
  local search_job = yoz.search.start_search_in_files(request.options)
  t:defer(function()
    search_job:dispose()
  end)

  local status, result, err
  t.wait_until(function()
    status, result, err = search_job:poll()
    return status ~= "running"
  end, 5000, "fixture search did not finish")
  assert(status == "completed", err and err.error or status)

  local context = request.context
  ---@diagnostic disable-next-line: param-type-mismatch
  local normalized = composer._treeview:normalize_search_result(context.params, result)
  composer:__apply_search_result__(context, normalized)
  treeview.await(composer.result.draw())

  local bufnr = t:buffer()
  treeview.await(composer.result.draw(bufnr))
  t.assert_true(composer._treeview:linecount() >= max_matches, "native frame must contain every match")
end

t:test("search inputs identify the root by its canonical path", function()
  local composer = new_composer("canonical-search-paths", 500)
  t:patch_table(composer._treeview, "is_current", function()
    return true
  end)
  composer.rootpath:next([[C:\workspace\project]], { silent = true })
  local inputs = composer:__snapshot_search_inputs__()
  t.assert_eq("C:/workspace/project", inputs.rootpath, "canonical request identity")
  treeview.await(composer.result.draw())
  composer._published_search_inputs = inputs
  composer.rootpath:next("C:/workspace/project", { silent = true })
  t.assert_true(composer:__is_search_projection_current__(), "canonical writeback identity")
  composer.rootpath:next("", { silent = true })
  t.assert_eq("", composer:__snapshot_search_inputs__().rootpath, "empty root identity")
end)

t:test("composer guards the pre-observer stale window and coalesces input bursts", function()
  local composer, controls = new_composer("file-search-integration", 500)
  composer.finder:create_buf()

  local generation = composer._file_search._generation
  composer.finder:set_content("needle")
  t.assert_eq(generation, composer._file_search._generation, "Observable notification should remain asynchronous")
  t.wait_until(function()
    return composer._file_search._generation == generation + 1
  end, 5000, "finder mutation did not invalidate")

  t.wait_until(function()
    return composer._file_search._active == nil and #composer._uuids_order == 1
  end, 5000, "controller did not publish the real native search")
  treeview.await(composer.result.draw())
  t.assert_true(composer:__is_search_projection_current__(), "published projection should match current inputs")

  local stale_request, snapshot_err = composer:__snapshot_search_request__()
  assert(stale_request ~= nil, snapshot_err)
  generation = composer._file_search._generation
  local replace_calls = 0
  t:patch_table(yoz.replace, "replace_file", function()
    replace_calls = replace_calls + 1
    return false, nil
  end)
  t:patch_table(yoz.replace, "replace_file_by_matches", function()
    replace_calls = replace_calls + 1
    return false, nil
  end)
  local reports = bootstrap.with_reporter(t)

  composer.finder:set_content("")
  t.assert_eq(generation, composer._file_search._generation, "race fixture must run before observer invalidation")
  t.assert_false(
    composer._file_search:__is_current__(generation, stale_request),
    "changed inputs must make the active request stale before generation invalidation"
  )
  t.assert_false(
    composer:__is_search_projection_current__(),
    "displayed results must become read-only as soon as their inputs are stale"
  )

  picker.action(composer, "searcher: replace all files")()
  picker.action(composer, "search: replace file")()
  t.assert_eq(0, replace_calls, "stale projection must not reach native replacement")
  t.assert_eq(2, #reports.warn, "stale replacement should explain why it was rejected")

  t.assert_eq(1, #composer._uuids_order, "queued observer must not have run yet")
  t.wait_until(function()
    return composer._file_search._generation == generation + 1 and #composer._uuids_order == 0
  end, 5000, "empty query did not invalidate and clear the projection")

  generation = composer._file_search._generation
  composer.finder:set_content("needle")
  controls.flag_regex:next(true)
  controls.flag_replace:next(true)
  t.wait_until(function()
    return composer._file_search._generation == generation + 1
  end, 5000, "input burst did not invalidate")
  -- Observe a window in which a second invalidation of the burst would land.
  vim.wait(20)
  t.assert_eq(generation + 1, composer._file_search._generation, "input burst must invalidate exactly once")
end)

t:test("search indicator follows the logical search lifecycle", function()
  local composer, controls = new_composer("file-search-indicator", 500)
  local title = "file-search test (cwd)"
  composer.finder:set_title(title)
  local spinner_frames = { "⡀", "⠄", "⠄" }
  local spinner_index = 0
  t:patch_table(stl.anim, "spinner", function()
    spinner_index = math.min(spinner_index + 1, #spinner_frames)
    return spinner_frames[spinner_index]
  end)

  controls.search_pattern:next("needle", { silent = true })
  composer:schedule_search()
  t.assert_true(composer._search_indicator_started_at ~= nil, "non-empty search must start the indicator lifecycle")
  t.assert_eq(title, vim.trim(composer.finder.title), "indicator must remain hidden during the flicker delay")

  composer._search_indicator_started_at = 0
  composer:__pulse_search_indicator__()
  t.assert_true(composer._search_indicator_frame ~= nil, "running heartbeat must advance the spinner")
  t.assert_true(vim.trim(composer.finder.title) ~= title, "visible spinner must decorate the Finder title")
  t.assert_true(vim.endswith(vim.trim(composer.finder.title), title), "spinner must preserve the dynamic Finder title")
  t.assert_eq("m_pk_search_spinner_aqua", composer.finder._title_render[1][2])

  composer:__pulse_search_indicator__()
  t.assert_eq("m_pk_search_spinner_blue", composer.finder._title_render[1][2], "a new frame must change color")

  title = "file-search test (workspace)"
  composer.finder:set_title(title)
  composer:__pulse_search_indicator__()
  t.assert_true(
    vim.endswith(vim.trim(composer.finder.title), title),
    "spinner must adopt a dynamic Finder title change while searching"
  )

  t.wait_until(function()
    return composer._file_search._active == nil and #composer._uuids_order == 1
  end, 5000, "indicator fixture search did not finish")
  t.assert_eq(nil, composer._search_indicator_started_at, "current completion must stop the indicator lifecycle")
  t.assert_eq(nil, composer._search_indicator_hl_index, "current completion must reset the color cycle")
  t.assert_eq(title, vim.trim(composer.finder.title), "current completion must restore the latest dynamic Finder title")

  controls.search_pattern:next("another", { silent = true })
  composer:schedule_search()
  t.assert_true(composer._search_indicator_started_at ~= nil)
  -- A request within the same tick would coalesce into the pending one.
  t.wait_until(function()
    return not composer._search_schedule_pending
  end, 5000, "the pending search request did not settle")
  controls.search_pattern:next("", { silent = true })
  composer:schedule_search()
  t.assert_eq(nil, composer._search_indicator_started_at, "empty query must stop the indicator lifecycle")
  t.assert_eq(title, vim.trim(composer.finder.title), "empty query must restore the Finder title")
end)

t:test("match limit status follows the published projection and blocks replace all", function()
  local composer, controls = new_composer("file-search-limit", 500)
  controls.search_pattern:next("needle")

  t.wait_until(function()
    return composer._file_search._active == nil and composer:__is_search_projection_current__()
  end, 5000, "limited search did not publish")
  t.assert_true(composer._published_search_limit_reached, "500-result projection should be marked limited")

  local replace_file_calls = 0
  local replace_match_calls = 0
  local replace_match_filepath = nil ---@type string|nil
  t:patch_table(yoz.replace, "replace_file", function()
    replace_file_calls = replace_file_calls + 1
    return false, nil
  end)
  t:patch_table(yoz.replace, "replace_file_by_matches", function(params)
    replace_match_calls = replace_match_calls + 1
    replace_match_filepath = params.filepath
    return false, nil
  end)
  local reports = bootstrap.with_reporter(t)

  picker.action(composer, "searcher: replace all files")()
  t.assert_eq(0, replace_file_calls, "limited projection must not reach native whole-file replacement")
  t.assert_eq(0, replace_match_calls, "limited projection must not reach native bulk replacement")
  t.assert_eq(1, #reports.warn, "limited bulk replacement should explain why it was rejected")

  local leafuuid = composer._uuids_order[1] ---@type string
  ---@diagnostic disable-next-line: assign-type-mismatch
  local leafdata = composer._filetree:get(leafuuid) ---@type era.view.result_paths.IFile
  ---@diagnostic disable-next-line: assign-type-mismatch
  local leafstate = composer._treeview:retrieve(leafuuid) ---@type era.view.result_tree.IEntry
  assert(leafdata ~= nil and leafstate ~= nil, "limited result leaf should exist")
  composer:__replace_file__(leafdata, leafstate)
  t.assert_eq(0, replace_file_calls, "limited node replacement must not replace undiscovered matches")
  t.assert_eq(1, replace_match_calls, "limited node replacement should use explicit visible match offsets")
  t.assert_eq(
    yoz.canonical_path.to_os_path(leafdata.filepath),
    replace_match_filepath,
    "limited replace filesystem boundary"
  )

  local advance_filepath = nil ---@type string|nil
  t:patch_table(yoz.replace, "replace_file_by_matches_advance", function(params)
    advance_filepath = params.filepath
    return { locations = {} }, nil
  end)
  local result_bufnr = t:buffer()
  treeview.await(composer.result.draw(result_bufnr))
  local location = assert(leafstate.locations and leafstate.locations[#leafstate.locations])
  local location_lnum = assert(composer._treeview:retrieve_lnum(location.locationuuid))
  composer.result:set_lnum_current(location_lnum)
  treeview.await(composer._treeview:ready())
  picker.action(composer, "search: replace file")()
  t.assert_eq(
    yoz.canonical_path.to_os_path(leafdata.filepath),
    advance_filepath,
    "single-match replace filesystem boundary"
  )
  vim.api.nvim_buf_delete(result_bufnr, { force = true })

  local winnr = composer.result:create_win({
    border = "single",
    number = false,
    winhighlight = "",
  }, {
    row = 0,
    col = 0,
    width = 80,
    height = 10,
  })
  t.wait_until(function()
    return vim.api.nvim_get_option_value("winbar", { win = winnr }):find("LIMIT 500", 1, true) ~= nil
  end, 5000, "limited projection should render a persistent status")
  local winbar = vim.api.nvim_get_option_value("winbar", { win = winnr }) ---@type string
  local rendered_winbar = vim.api.nvim_eval_statusline(winbar, { winid = winnr, maxwidth = 80 }).str ---@type string
  local limit_start = assert(rendered_winbar:find(" LIMIT 500 ", 1, true), "limited status should be rendered")
  local limit_prefix = rendered_winbar:sub(1, limit_start - 1) ---@type string
  local limit_center = vim.api.nvim_strwidth(limit_prefix) + vim.api.nvim_strwidth(" LIMIT 500 ") / 2 ---@type number
  t.assert_true(math.abs(limit_center - 40) <= 0.5, "limited projection status should be centered")

  controls.flag_limit_matches:next(false)
  t.assert_true(
    composer._published_search_limit_reached,
    "changing future request settings must not rewrite the displayed projection status"
  )
  t.assert_false(composer:__is_search_projection_current__(), "the bounded projection should become stale immediately")

  t.wait_until(function()
    return composer._file_search._active == nil
      and composer:__is_search_projection_current__()
      and not composer._published_search_limit_reached
  end, 10000, "unlimited search did not replace the limited projection")
  t.wait_until(function()
    return vim.api.nvim_get_option_value("winbar", { win = winnr }):find("LIMIT", 1, true) == nil
  end, 5000, "exhaustive projection should clear the limit status")
  winbar = vim.api.nvim_get_option_value("winbar", { win = winnr }) ---@type string
  t.assert_true(winbar:find("LIMIT", 1, true) == nil, "exhaustive projection should clear the limit status")
end)

t:test("500-result normal and replace-preview publications contain every match", function()
  assert_publishes_every_match(false, 500)
  assert_publishes_every_match(true, 500)
end)

t:test("5000-result publication contains every match", function()
  assert_publishes_every_match(false, 5000)
end)

t:run()
