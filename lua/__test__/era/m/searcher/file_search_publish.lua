---@diagnostic disable: invisible
--- Run with: nvim -l lua/__test__/era/m/searcher/file_search_publish.lua

local harness = require("__test__.harness")
require("ark.bootstrap").setup()

local t = harness.new("era.m.searcher file-search publish")

local fixture_dir = vim.fn.tempname()
assert(vim.fn.mkdir(fixture_dir, "p") == 1)
local fixture_path = vim.fs.joinpath(fixture_dir, "matches.txt")
local fixture_lines = {} ---@type string[]
for index = 1, 5000 do
  fixture_lines[index] = string.format("needle line %04d", index)
end
vim.fn.writefile(fixture_lines, fixture_path)

---@param value                         unknown
---@return stl.c.Observable
local function observable(value)
  return stl.c.Observable.from_value(value)
end

---@param name                          string
---@param max_matches                   integer
---@return era.m.searcher.FiletreeComposer
---@return table
local function new_composer(name, max_matches)
  local controls = {
    search_pattern = observable(""),
    replace_pattern = observable(""),
    flag_regex = observable(false),
    flag_replace = observable(false),
    max_matches = observable(max_matches),
  }
  local composer = era.m.searcher.FiletreeComposer.new({
    name = name,
    permanent = false,
    preview = false,
    title = "file-search test",

    excludes = observable({}),
    flag_exclude = observable(false),
    flag_foldempty = observable(false),
    flag_gitignore = observable(false),
    flag_regex = controls.flag_regex,
    flag_replace = controls.flag_replace,
    flag_case_sensitive = observable(true),
    flag_selected = observable(false),
    flag_viewtype = observable("tree"),
    includes = observable({ "*.txt" }),
    max_filesize = observable("1M"),
    max_matches = controls.max_matches,
    replace_pattern = controls.replace_pattern,
    rootpath = observable(fixture_dir),
    search_pattern = controls.search_pattern,
  })
  return composer, controls
end

---@param flag_replace                  boolean
---@param max_matches                   integer
---@return { total: number, poll: number, normalize: number, apply: number, render: number }
local function benchmark(flag_replace, max_matches)
  local composer, controls =
    new_composer(string.format("publish-benchmark-%s-%d", tostring(flag_replace), max_matches), max_matches)

  vim.wait(20)
  controls.search_pattern:next("needle", { silent = true })
  controls.replace_pattern:next("replacement", { silent = true })
  controls.flag_replace:next(flag_replace, { silent = true })
  controls.max_matches:next(max_matches, { silent = true })

  local request, snapshot_err = composer:__snapshot_search_request__()
  assert(request ~= nil, snapshot_err)
  local search_job = yoz.search.start_search_in_files(request.options)
  local timing = nil ---@type table|nil

  t.wait_until(function()
    local poll_started = vim.uv.hrtime()
    local status, result, err = search_job:poll()
    if status == "running" then
      return false
    end
    assert(status == "completed", err and err.error or status)

    local poll_ms = (vim.uv.hrtime() - poll_started) / 1e6
    local context = request.context
    local normalize_started = vim.uv.hrtime()
    local normalized = composer._treeview:normalize_search_result(context.params, result)
    local normalize_ms = (vim.uv.hrtime() - normalize_started) / 1e6

    local apply_started = vim.uv.hrtime()
    composer:__apply_search_result__(context, normalized)
    local apply_ms = (vim.uv.hrtime() - apply_started) / 1e6

    local bufnr = vim.api.nvim_create_buf(false, true)
    local render_started = vim.uv.hrtime()
    composer.result.draw(bufnr)
    local render_ms = (vim.uv.hrtime() - render_started) / 1e6
    local extmarks = vim.api.nvim_buf_get_extmarks(bufnr, dot.var.nsnr.view_tree, 0, -1, {})
    local minimum_extmarks = max_matches * (flag_replace and 3 or 2)
    assert(#extmarks >= minimum_extmarks, "expected inline and indent highlights")
    timing = {
      total = poll_ms + normalize_ms + apply_ms + render_ms,
      poll = poll_ms,
      normalize = normalize_ms,
      apply = apply_ms,
      render = render_ms,
    }
    vim.api.nvim_buf_delete(bufnr, { force = true })
    return true
  end, 5000, "publish benchmark search did not finish")

  search_job:dispose()
  composer:dispose()
  vim.wait(20)
  return assert(timing)
end

t:test("Finder renders a highlighted title accent without changing its plain-title contract", function()
  local input = observable("")
  local finder = era.m.searcher.Finder.new({
    name = "finder-title-accent",
    keymaps = {},
    input = input,
    title = "Search Files",
  })
  local winnr = finder:create_win({
    border = "single",
    winhighlight = "",
  }, {
    row = 0,
    col = 0,
    width = 40,
    height = 1,
  })

  finder:set_title("Search Files", {
    text = "⡀",
    hl = "m_pk_search_spinner_aqua",
  })
  local title = vim.api.nvim_win_get_config(winnr).title
  t.assert_eq(" ⡀ Search Files ", finder.title)
  t.assert_eq(" ⡀", title[1][1])
  t.assert_eq("m_pk_search_spinner_aqua", title[1][2])
  t.assert_eq(" Search Files ", title[2][1])
  t.assert_eq(nil, title[2][2], "title text must retain the window's FloatTitle highlight")

  finder:set_title("Search Files")
  title = vim.api.nvim_win_get_config(winnr).title
  t.assert_eq(" Search Files ", finder._title_render)
  t.assert_eq(" Search Files ", title[1][1])
  t.assert_eq(nil, title[1][2])

  finder:dispose()
  input:dispose()
end)

t:test("composer guards the pre-observer stale window and coalesces input bursts", function()
  local composer, controls = new_composer("file-search-integration", 500)
  vim.wait(20)
  composer.finder:create_buf()

  local generation = composer._file_search._generation
  composer.finder:set_content("needle")
  t.assert_eq(generation, composer._file_search._generation, "Observable notification should remain asynchronous")
  t.wait_until(function()
    return composer._file_search._generation == generation + 1
  end, 100, "finder mutation did not invalidate")

  t.wait_until(function()
    return composer._file_search._active == nil and #composer._uuids_order == 1
  end, 5000, "controller did not publish the real native search")
  t.assert_true(composer:__is_search_projection_current__(), "published projection should match current inputs")

  local stale_request, snapshot_err = composer:__snapshot_search_request__()
  assert(stale_request ~= nil, snapshot_err)
  generation = composer._file_search._generation
  local replace_calls = 0
  local warnings = 0
  t:patch_table(yoz.replace, "replace_file", function()
    replace_calls = replace_calls + 1
    return false, nil
  end)
  t:patch_table(yoz.replace, "replace_file_by_matches", function()
    replace_calls = replace_calls + 1
    return false, nil
  end)
  t:patch_table(stl.reporter, "warn", function()
    warnings = warnings + 1
  end)

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

  local replace_all, replace_in_node ---@type fun(): nil, fun(): nil
  for _, keymap in ipairs(composer.finder.keymaps) do
    if keymap.desc == "searcher: replace all files" then
      replace_all = keymap.callback
    elseif keymap.desc == "search: replace file" then
      replace_in_node = keymap.callback
    end
  end
  assert(replace_all ~= nil, "replace-all action should be bound")
  assert(replace_in_node ~= nil, "replace-in-node action should be bound")
  replace_all()
  replace_in_node()
  t.assert_eq(0, replace_calls, "stale projection must not reach native replacement")
  t.assert_eq(2, warnings, "stale replacement should explain why it was rejected")

  t.assert_eq(1, #composer._uuids_order, "queued observer must not have run yet")
  t.wait_until(function()
    return composer._file_search._generation == generation + 1 and #composer._uuids_order == 0
  end, 100, "empty query did not invalidate and clear the projection")

  generation = composer._file_search._generation
  composer.finder:set_content("needle")
  controls.flag_regex:next(true)
  controls.flag_replace:next(true)
  t.wait_until(function()
    return composer._file_search._generation == generation + 1
  end, 100, "input burst did not invalidate")
  vim.wait(20)
  t.assert_eq(generation + 1, composer._file_search._generation, "input burst must invalidate exactly once")

  composer:dispose()
  vim.wait(20)
end)

t:test("search indicator follows the logical search lifecycle", function()
  local composer, controls = new_composer("file-search-indicator", 500)
  vim.wait(20)
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
  vim.wait(1)
  controls.search_pattern:next("", { silent = true })
  composer:schedule_search()
  t.assert_eq(nil, composer._search_indicator_started_at, "empty query must stop the indicator lifecycle")
  t.assert_eq(title, vim.trim(composer.finder.title), "empty query must restore the Finder title")

  composer:dispose()
  vim.wait(20)
end)

t:test("500-result normal and replace-preview publication stay below 50ms", function()
  local normal = benchmark(false, 500)
  local replace = benchmark(true, 500)
  io.stdout:write(
    string.format(
      "\nBENCH 500 normal=%.3fms [poll %.3f normalize %.3f apply %.3f render %.3f] "
        .. "replace=%.3fms [poll %.3f normalize %.3f apply %.3f render %.3f]\n",
      normal.total,
      normal.poll,
      normal.normalize,
      normal.apply,
      normal.render,
      replace.total,
      replace.poll,
      replace.normalize,
      replace.apply,
      replace.render
    )
  )
  t.assert_true(normal.total < 50, string.format("normal publish took %.3fms", normal.total))
  t.assert_true(replace.total < 50, string.format("replace publish took %.3fms", replace.total))
end)

t:test("5000-result stress publication is recorded without a responsiveness guarantee", function()
  local stress = benchmark(false, 5000)
  io.stdout:write(
    string.format(
      "\nBENCH 5000 stress=%.3fms [poll %.3f normalize %.3f apply %.3f render %.3f]\n",
      stress.total,
      stress.poll,
      stress.normalize,
      stress.apply,
      stress.render
    )
  )
end)

local test_result = t:run({ exit = false })
vim.fn.delete(fixture_dir, "rf")
os.exit(test_result.failed > 0 and 1 or 0)
