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
---@param preview                       boolean|nil
---@return era.m.searcher.FiletreeComposer
---@return table
local function new_composer(name, max_matches, preview)
  local controls = {
    search_pattern = observable(""),
    replace_pattern = observable(""),
    flag_limit_matches = observable(true),
    flag_regex = observable(false),
    flag_replace = observable(false),
    max_matches = observable(max_matches),
  }
  local composer = era.m.searcher.FiletreeComposer.new({
    name = name,
    permanent = false,
    preview = preview == true,
    title = "file-search test",

    excludes = observable({}),
    flag_exclude = observable(false),
    flag_foldempty = observable(false),
    flag_gitignore = observable(false),
    flag_limit_matches = controls.flag_limit_matches,
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

t:test("preview treats an empty result as a normal state", function()
  local basic_props = nil ---@type era.m.searcher.composer.IBasicProps|nil
  local original_new = era.m.searcher.BasicComposer.new
  t:patch_table(era.m.searcher.BasicComposer, "new", function(props)
    basic_props = props
    return original_new(props)
  end)

  local composer = new_composer("empty-preview", 500, true)

  local bufnr = vim.api.nvim_create_buf(false, true)
  local ok, err = pcall(function()
    ---@diagnostic disable-next-line: undefined-field
    assert(basic_props ~= nil and basic_props.render_preview ~= nil, "preview renderer should be captured")
    vim.api.nvim_buf_set_lines(bufnr, 0, -1, false, { "stale preview" })
    composer._last_preview_filepath = "stale.lua"
    ---@diagnostic disable-next-line: duplicate-set-field
    composer.__retrieve_nodeuuid__ = function()
      return nil, 0
    end

    ---@diagnostic disable-next-line: undefined-field
    local result = basic_props.render_preview(bufnr, false)
    t.assert_eq("", vim.api.nvim_buf_get_lines(bufnr, 0, 1, false)[1], "empty preview content")
    t.assert_eq("", result.title, "empty preview title")
    t.assert_false(result.cursorline, "empty preview cursorline")
    t.assert_false(result.number, "empty preview number")
    t.assert_false(result.wrap, "empty preview wrap")
    t.assert_false(result.whitespaces, "empty preview whitespace markers")
    t.assert_nil(composer._last_preview_filepath, "empty preview invalidates cached filepath")

    ---@diagnostic disable-next-line: duplicate-set-field
    composer.__retrieve_nodeuuid__ = function()
      return nil, -1
    end
    ---@diagnostic disable-next-line: undefined-field
    result = basic_props.render_preview(bufnr, false)
    t.assert_eq("Unknown lnum(-1)", result.title, "invalid nonzero line remains diagnostic")
  end)

  if vim.api.nvim_buf_is_valid(bufnr) then
    vim.api.nvim_buf_delete(bufnr, { force = true })
  end
  composer:dispose()
  vim.wait(20)
  if not ok then
    error(err, 0)
  end
end)

t:test("search publication rebuild preserves only-selected projection", function()
  local composer = new_composer("selected-publication", 500)
  local view = composer._treeview
  local fileuuid = stl.c.Filetree.uuid(fixture_path)
  local bufnr = vim.api.nvim_create_buf(false, true)
  local ok, err = pcall(function()
    view:reset_filepaths(fixture_dir, { fixture_path })
    view:set_selected(fileuuid, true)
    view:reset_filepaths(fixture_dir, { fixture_path })

    t.assert_true(view:isselected(fileuuid), "selected file restored")
    local result = view:render_listview({
      bufnr = bufnr,
      rootuuid = view._tree.root,
      orders = nil,
      only_matched = false,
      only_selected = true,
      only_visible = true,
    })
    t.assert_true(#result.lnum2uuid > 0, "only-selected projection")
    t.assert_eq(fileuuid, result.lnum2uuid[#result.lnum2uuid], "selected file projection")
  end)

  if vim.api.nvim_buf_is_valid(bufnr) then
    vim.api.nvim_buf_delete(bufnr, { force = true })
  end
  composer:dispose()
  vim.wait(20)
  if not ok then
    error(err, 0)
  end
end)

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
    ---@diagnostic disable-next-line: param-type-mismatch
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

t:test("native search paths cross the OS boundary and publish canonical identities", function()
  local composer = new_composer("canonical-search-paths", 500)
  local ok, err = pcall(function()
    composer.rootpath:next([[C:\workspace\project]], { silent = true })
    local inputs = composer:__snapshot_search_inputs__()
    t.assert_eq("C:/workspace/project", inputs.rootpath, "canonical request identity")
    composer._published_search_inputs = inputs
    composer.rootpath:next("C:/workspace/project", { silent = true })
    t.assert_true(composer:__is_search_projection_current__(), "canonical writeback identity")
    composer.rootpath:next("", { silent = true })
    t.assert_eq("", composer:__snapshot_search_inputs__().rootpath, "empty root identity")

    ---@type era.m.searcher.view.filetree.ISearchParams
    local params = {
      cwd = "C:/workspace/project",
      specified_filepath = "C:/workspace/project/src/main.lua",
      excludes = {},
      includes = { "*.lua" },
      flag_case_sensitive = true,
      flag_exclude = false,
      flag_gitignore = false,
      flag_regex = false,
      flag_replace = false,
      max_filesize = "1M",
      max_matches = 500,
      search_pattern = "needle",
      replace_pattern = nil,
    }

    t:patch_table(yoz.canonical_path, "to_os_path", function(filepath)
      return "OS<" .. filepath .. ">"
    end)
    local options = composer._treeview:build_search_options(params)
    t.assert_eq("OS<C:/workspace/project>", options.cwd, "native search cwd")
    t.assert_eq("OS<C:/workspace/project/src/main.lua>", options.specified_filepath, "native specified filepath")

    ---@diagnostic disable-next-line: missing-fields
    local result = composer._treeview:normalize_search_result(params, {
      items = {
        { p = [[src\main.lua]], matches = {} },
        { p = [[D:\archive\outside.lua]], matches = {} },
      },
      limit_reached = false,
    })
    local expected = {
      "C:/workspace/project/src/main.lua",
      "D:/archive/outside.lua",
    } ---@type string[]
    for _, filepath in ipairs(expected) do
      local filematch = result.filematch_map[stl.c.Filetree.uuid(filepath)]
      t.assert_true(filematch ~= nil, "published filepath: " .. filepath)
      t.assert_eq(filepath, filematch and filematch.filepath, "canonical published filepath")
      t.assert_false(filematch and filematch.relative:find("\\", 1, true) ~= nil, "canonical relative filepath")
    end
  end)

  composer:dispose()
  vim.wait(20)
  if not ok then
    error(err, 0)
  end
end)

t:test("preview keeps canonical identity across filesystem boundaries", function()
  local composer, controls = new_composer("canonical-preview-paths", 500)
  local ok, err = pcall(function()
    local filepath = "C:/workspace/project/src/main.lua"
    t:patch_table(yoz.canonical_path, "to_os_path", function(value)
      return "OS<" .. value .. ">"
    end)

    local preview_filepath = nil ---@type string|nil
    t:patch_table(yoz.replace, "replace_file_preview_by_matches_advance", function(params)
      preview_filepath = params.filepath
      return { text = "needle", matches = {} }, nil
    end)
    controls.flag_replace:next(true, { silent = true })
    controls.replace_pattern:next("replacement", { silent = true })

    local context = {
      flag_case_sensitive = composer.flag_case_sensitive,
      flag_regex = composer.flag_regex,
      flag_replace = composer.flag_replace,
      search_pattern = composer.search_pattern,
      replace_pattern = composer.replace_pattern,
      filepath = filepath,
      filematch = nil,
      offset_current = -1,
      match_offsets = {},
    } ---@type era.m.searcher.IPlainfileViewContext
    ---@diagnostic disable-next-line: assign-type-mismatch
    local data = composer._plainfile:calc_preview_data(context)
    t.assert_eq("OS<" .. filepath .. ">", preview_filepath, "native preview filepath")
    t.assert_eq(filepath, data.filepath, "canonical preview identity")

    local read_filepath = nil ---@type string|nil
    t:patch_table(stl.fs, "read_file_as_lines", function(params)
      read_filepath = params.filepath
      return {}
    end)
    controls.flag_replace:next(false, { silent = true })
    ---@diagnostic disable-next-line: cast-local-type
    data = composer._plainfile:calc_preview_data(context)
    t.assert_eq("OS<" .. filepath .. ">", read_filepath, "filesystem preview filepath")
    t.assert_eq(filepath, data.filepath, "canonical read identity")
  end)

  composer:dispose()
  vim.wait(20)
  if not ok then
    error(err, 0)
  end
end)

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
  ---@diagnostic disable-next-line: need-check-nil
  t.assert_eq(" ⡀", title[1][1])
  ---@diagnostic disable-next-line: need-check-nil
  t.assert_eq("m_pk_search_spinner_aqua", title[1][2])
  ---@diagnostic disable-next-line: need-check-nil
  t.assert_eq(" Search Files ", title[2][1])
  ---@diagnostic disable-next-line: need-check-nil
  t.assert_eq(nil, title[2][2], "title text must retain the window's FloatTitle highlight")

  finder:set_title("Search Files")
  title = vim.api.nvim_win_get_config(winnr).title
  t.assert_eq(" Search Files ", finder._title_render)
  ---@diagnostic disable-next-line: need-check-nil
  t.assert_eq(" Search Files ", title[1][1])
  ---@diagnostic disable-next-line: need-check-nil
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
      ---@diagnostic disable-next-line: cast-local-type
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

t:test("match limit status follows the published projection and blocks replace all", function()
  local composer, controls = new_composer("file-search-limit", 500)
  vim.wait(20)
  controls.search_pattern:next("needle")

  t.wait_until(function()
    return composer._file_search._active == nil and composer:__is_search_projection_current__()
  end, 5000, "limited search did not publish")
  t.assert_true(composer._published_search_limit_reached, "500-result projection should be marked limited")

  local replace_file_calls = 0
  local replace_match_calls = 0
  local replace_match_filepath = nil ---@type string|nil
  local warnings = 0
  t:patch_table(yoz.replace, "replace_file", function()
    replace_file_calls = replace_file_calls + 1
    return false, nil
  end)
  t:patch_table(yoz.replace, "replace_file_by_matches", function(params)
    replace_match_calls = replace_match_calls + 1
    replace_match_filepath = params.filepath
    return false, nil
  end)
  t:patch_table(stl.reporter, "warn", function()
    warnings = warnings + 1
  end)

  local replace_all ---@type fun(): nil
  for _, keymap in ipairs(composer.finder.keymaps) do
    if keymap.desc == "searcher: replace all files" then
      ---@diagnostic disable-next-line: cast-local-type
      replace_all = keymap.callback
      break
    end
  end
  assert(replace_all ~= nil, "replace-all action should be bound")
  replace_all()
  t.assert_eq(0, replace_file_calls, "limited projection must not reach native whole-file replacement")
  t.assert_eq(0, replace_match_calls, "limited projection must not reach native bulk replacement")
  t.assert_eq(1, warnings, "limited bulk replacement should explain why it was rejected")

  local leafuuid = composer._uuids_order[1] ---@type string
  ---@diagnostic disable-next-line: assign-type-mismatch
  local leafdata = composer._filetree:get(leafuuid) ---@type stl.c.IFiletreeNodeData
  ---@diagnostic disable-next-line: assign-type-mismatch
  local leafstate = composer._treeview:retrieve(leafuuid) ---@type era.m.searcher.view.filetree.IFileNodeState
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
  local result_bufnr = vim.api.nvim_create_buf(false, true)
  composer.result.draw(result_bufnr)
  local location = assert(leafstate.locations and leafstate.locations[#leafstate.locations])
  local location_lnum = assert(composer._retriever:retrieve_lnum(location.locationuuid))
  composer.result.lnum_current:next(location_lnum, { force = true })
  local replace_in_node ---@type fun(): nil
  for _, keymap in ipairs(composer.finder.keymaps) do
    if keymap.desc == "search: replace file" then
      ---@diagnostic disable-next-line: cast-local-type
      replace_in_node = keymap.callback
      break
    end
  end
  assert(replace_in_node ~= nil, "replace-in-node action should be bound")
  replace_in_node()
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
  local winbar = vim.api.nvim_get_option_value("winbar", { win = winnr }) ---@type string
  t.assert_true(winbar:find("LIMIT 500", 1, true) ~= nil, "limited projection should render a persistent status")
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
  vim.wait(150)
  winbar = vim.api.nvim_get_option_value("winbar", { win = winnr }) ---@type string
  t.assert_true(winbar:find("LIMIT", 1, true) == nil, "exhaustive projection should clear the limit status")

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
