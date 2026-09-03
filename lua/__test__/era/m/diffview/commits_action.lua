---@diagnostic disable: undefined-global
--- Run with: nvim -l lua/__test__/era/m/diffview/commits_action.lua

local harness = require("__test__.harness")

local t = harness.new("era.m.diffview.commits_action")
local line_maps = {} ---@type table<integer, era.m.diffview.ICommitsLineMap[]>
local reports = {} ---@type table[]
local dirty_count = 0 ---@type integer
local search_match = nil ---@type era.m.diffview.ICommitSearchMatch|nil
local search_error = nil ---@type string|nil
local search_query = nil ---@type string|nil
local search_path = nil ---@type string|nil
local fetched_page = nil ---@type integer|nil
local fetched_per_page = nil ---@type integer|nil
local page_commits = {} ---@type era.m.diffview.ICommit[]

local pane_commits = {
  apply_to_buffer = function(bufnr, result)
    vim.api.nvim_buf_set_lines(bufnr, 0, -1, false, result.lines)
    line_maps[bufnr] = result.line_map
  end,
  apply_winopts = function() end,
  create_buffer = function()
    return vim.api.nvim_create_buf(false, true)
  end,
  find_commit_line = function(line_map, hash)
    for lnum, item in ipairs(line_map) do
      if item.type == "commit" and item.commit.hash == hash then
        return lnum
      end
    end
  end,
  find_file_line = function(line_map, hash, filepath)
    for lnum, item in ipairs(line_map) do
      if item.type == "file" and item.commit.hash == hash and item.entry and item.entry.filepath == filepath then
        return lnum
      end
    end
  end,
  get_line_map = function(bufnr)
    return line_maps[bufnr]
  end,
  get_item_at_line = function(bufnr, lnum)
    local line_map = line_maps[bufnr]
    return line_map and line_map[lnum] or nil
  end,
  render = function(commits, expanded)
    local lines = {} ---@type string[]
    local line_map = {} ---@type era.m.diffview.ICommitsLineMap[]
    for _, commit in ipairs(commits) do
      lines[#lines + 1] = commit.hash
      line_map[#line_map + 1] = { type = "commit", commit = commit }
      if expanded[commit.hash] then
        for _, entry in ipairs(commit.files or {}) do
          lines[#lines + 1] = entry.filepath
          line_map[#line_map + 1] = { type = "file", commit = commit, entry = entry }
        end
      end
    end
    return { lines = lines, highlights = {}, line_map = line_map }
  end,
}

t:patch_global("dot", {
  state = {
    status = {
      dirtier_tabline = {
        mark_dirty = function()
          dirty_count = dirty_count + 1
        end,
      },
    },
  },
})
t:patch_global("era", {})
t:patch_global("stl", {
  async = {
    run = function(callback)
      callback()
    end,
    scheduler = function() end,
  },
  reporter = {
    warn = function(report)
      reports[#reports + 1] = report
    end,
  },
})
t:patch_table(package.loaded, "era.m.diffview.config", { COMMITS_PER_PAGE = 100, COMMITS_WIDTH = 20 })
local action_data = {
  find_log_commit = function(query, path_filter)
    search_query = query
    search_path = path_filter
    return search_match, search_error
  end,
  fetch_log_page = function(page, per_page)
    fetched_page = page
    fetched_per_page = per_page
    return page_commits
  end,
}
t:patch_table(package.loaded, "era.m.diffview.data", action_data)
t:patch_table(package.loaded, "era.m.diffview.layout", {})
t:patch_table(package.loaded, "era.m.diffview.pane.commits", pane_commits)
t:patch_table(package.loaded, "era.m.diffview.pane.filetree", {})
t:patch_table(package.loaded, "era.m.diffview.pane.sbs", {})
t:patch_table(package.loaded, "era.m.diffview.util", {
  workspace_path = function(filepath)
    return "/repo/" .. filepath
  end,
})
t:patch_table(package.loaded, "era.m.diffview.view.commits.keymap", {
  setup_commits = function() end,
})
t:patch_table(package.loaded, "era.m.diffview.view.commits.state", {})

local view = assert(loadfile("lua/era/m/diffview/view/commits/view.lua"))()
t:patch_table(package.loaded, "era.m.diffview.view.commits.view", view)
local action = assert(loadfile("lua/era/m/diffview/view/commits/action.lua"))()
t:patch_table(package.loaded, "era.m.diffview.view.commits.action", action)
local keymap = assert(loadfile("lua/era/m/diffview/view/commits/keymap.lua"))()

local function reset_search()
  reports = {}
  dirty_count = 0
  search_match = nil
  search_error = nil
  search_query = nil
  search_path = nil
  fetched_page = nil
  fetched_per_page = nil
  page_commits = {}
end

---@return table
local function new_search_state()
  local state = {
    commits = {},
    current_commit = nil,
    current_entry = { filepath = "stale.lua" },
    expanded = { stale = true },
    page = 1,
    total = 100,
    path_filter = "lua/ark/autocmd.lua",
    content_generation = 0,
    page_applied = 1,
  }
  state.expanded_commits = {
    next = function(_, value)
      state.expanded = value
    end,
  }
  function state:get_commits()
    return self.commits
  end
  function state:get_expanded_commits()
    return self.expanded
  end
  function state:get_commit_collapsed_dirs()
    return {}
  end
  function state:get_path_filter()
    return self.path_filter
  end
  function state:get_commits_page()
    return self.page
  end
  function state:get_commits_page_count()
    return math.max(1, math.ceil(self.total / 100))
  end
  function state:request_commits_page(value)
    self.page = value
  end
  function state:reset_commits_page()
    self.page = self.page_applied
  end
  function state:begin_content_request()
    self.content_generation = self.content_generation + 1
    return self.content_generation
  end
  function state:owns_content_request(generation)
    return self.content_generation == generation
  end
  function state:set_commits(value)
    self.commits = value
  end
  function state:set_commits_page(value)
    self.page = value
    self.page_applied = value
  end
  function state:set_commits_total(value)
    self.total = value
  end
  function state:set_current_commit(value)
    self.current_commit = value
  end
  function state:set_current_entry(value)
    self.current_entry = value
  end
  function state:set_lnum_present(value)
    self.lnum_present = value
  end
  return state
end

t:test("commit details popup opens above a trigger near the bottom", function()
  local anchor_row = vim.o.lines - 3 ---@type integer
  action.__show_commit_popup__("abc123", { "commit abc123", "Author: Alice" }, {
    row = anchor_row,
    col = 1,
  })

  local popup_winnr = vim.api.nvim_get_current_win() ---@type integer
  local config = vim.api.nvim_win_get_config(popup_winnr)
  t.assert_eq("editor", config.relative, "editor-relative captured position")
  t.assert_eq(anchor_row - config.height - 2, config.row, "popup above trigger row")
  t.assert_true(config.row ~= math.floor((vim.o.lines - config.height) / 2), "popup is not centered")

  vim.api.nvim_win_close(popup_winnr, true)
end)

t:test("hide_commits keeps a commits-only tab alive", function()
  local original_tabnr = vim.api.nvim_get_current_tabpage()
  vim.cmd.tabnew()
  local tabnr = vim.api.nvim_get_current_tabpage()
  local commits_winnr = vim.api.nvim_get_current_win()
  local commits_bufnr = pane_commits.create_buffer()
  vim.api.nvim_win_set_buf(commits_winnr, commits_bufnr)
  local lyt = {
    tabnr = tabnr,
    layout_type = 4,
    commits_winnr = commits_winnr,
    commits_bufnr = commits_bufnr,
  }

  view.hide_commits(lyt)

  t.assert_true(vim.api.nvim_tabpage_is_valid(tabnr), "commits-only tab")
  t.assert_true(vim.api.nvim_win_is_valid(commits_winnr), "last window")
  t.assert_eq(commits_winnr, lyt.commits_winnr, "layout reference")

  vim.cmd.tabclose()
  vim.api.nvim_set_current_tabpage(original_tabnr)
  if vim.api.nvim_buf_is_valid(commits_bufnr) then
    vim.api.nvim_buf_delete(commits_bufnr, { force = true })
  end
end)

t:test("reveal expands and focuses the active file, then hides Commits", function()
  local original_tabnr = vim.api.nvim_get_current_tabpage()
  vim.cmd.tabnew()
  local tabnr = vim.api.nvim_get_current_tabpage()
  local sbs_winnr = vim.api.nvim_get_current_win()
  local entry = { filepath = "src/a.lua", status = "M" }
  local commit = { hash = "abc123", files = { entry } }
  local expanded = false
  local state = {
    get_commits = function()
      return { commit }
    end,
    get_current_commit = function()
      return commit
    end,
    get_current_entry = function()
      return entry
    end,
    get_expanded_commits = function()
      return expanded and { [commit.hash] = true } or {}
    end,
    get_commit_collapsed_dirs = function()
      return {}
    end,
    is_commit_expanded = function()
      return expanded
    end,
    toggle_commit_expanded = function()
      expanded = not expanded
    end,
  }
  local lyt = {
    tabnr = tabnr,
    layout_type = 3,
    commits_winnr = nil,
    commits_bufnr = nil,
    sbs_left_winnr = sbs_winnr,
  }
  local ctx = { layout = lyt, state = state }

  action.reveal(ctx)
  local commits_winnr = assert(lyt.commits_winnr)
  local commits_bufnr = assert(lyt.commits_bufnr)
  t.assert_true(expanded, "active commit expanded")
  t.assert_eq(commits_winnr, vim.api.nvim_get_current_win(), "Commits focused")
  t.assert_eq(2, vim.api.nvim_win_get_cursor(commits_winnr)[1], "active file cursor")

  action.reveal(ctx)
  t.assert_true(vim.api.nvim_tabpage_is_valid(tabnr), "tab remains valid")
  t.assert_nil(lyt.commits_winnr, "Commits hidden")
  t.assert_eq(sbs_winnr, vim.api.nvim_get_current_win(), "SBS retained")

  vim.cmd.tabclose()
  vim.api.nvim_set_current_tabpage(original_tabnr)
  if vim.api.nvim_buf_is_valid(commits_bufnr) then
    vim.api.nvim_buf_delete(commits_bufnr, { force = true })
  end
end)

t:test("search jumps across pages and selects the matching commit", function()
  reset_search()
  local original_tabnr = vim.api.nvim_get_current_tabpage()
  vim.cmd.tabnew()
  local tabnr = vim.api.nvim_get_current_tabpage()
  local commits_winnr = vim.api.nvim_get_current_win()
  local commits_bufnr = pane_commits.create_buffer()
  vim.api.nvim_win_set_buf(commits_winnr, commits_bufnr)
  local target = { hash = "target", abbrev_hash = "target", parents = {}, author = "A", date = 0, message = "target" }
  search_match = { hash = target.hash, position = 103, total = 151 }
  page_commits = {
    { hash = "other", abbrev_hash = "other", parents = {}, author = "A", date = 0, message = "other" },
    target,
  }
  local state = new_search_state()
  local ctx = {
    layout = { tabnr = tabnr, layout_type = 4, commits_winnr = commits_winnr, commits_bufnr = commits_bufnr },
    state = state,
  }
  t:patch_table(vim.ui, "input", function(opts, callback)
    t.assert_eq("Commit hash or message: ", opts.prompt, "search prompt")
    callback("  target  ")
  end)

  action.search_commit(ctx)

  t.assert_eq("target", search_query, "trimmed query")
  t.assert_eq("lua/ark/autocmd.lua", search_path, "path filter")
  t.assert_eq(2, fetched_page, "target page")
  t.assert_eq(100, fetched_per_page, "page size")
  t.assert_eq(2, state.page, "state page")
  t.assert_eq(151, state.total, "state total")
  t.assert_true(state.current_commit == target, "current commit")
  t.assert_nil(state.current_entry, "stale entry")
  t.assert_nil(next(state.expanded), "expanded commits")
  t.assert_eq(2, state.lnum_present, "present line")
  t.assert_eq(2, vim.api.nvim_win_get_cursor(commits_winnr)[1], "cursor line")
  t.assert_eq(1, dirty_count, "tabline refresh")

  vim.cmd.tabclose()
  vim.api.nvim_set_current_tabpage(original_tabnr)
  if vim.api.nvim_buf_is_valid(commits_bufnr) then
    vim.api.nvim_buf_delete(commits_bufnr, { force = true })
  end
end)

t:test("search keeps only the latest overlapping result", function()
  reset_search()
  local first = { hash = "first", abbrev_hash = "first", author = "A", date = 0, message = "first" }
  local second = { hash = "second", abbrev_hash = "second", author = "A", date = 0, message = "second" }
  local state = new_search_state()
  local ctx = { layout = { layout_type = 4 }, state = state }
  local inputs = { "first", "second" }
  t:patch_table(vim.ui, "input", function(_, callback)
    callback(table.remove(inputs, 1))
  end)
  t:patch_table(action_data, "find_log_commit", function(query)
    if query == "first" then
      action.search_commit(ctx)
      return { hash = first.hash, position = 1, total = 2 }, nil
    end
    return { hash = second.hash, position = 2, total = 2 }, nil
  end)
  t:patch_table(action_data, "fetch_log_page", function()
    return { first, second }
  end)

  action.search_commit(ctx)

  t.assert_true(state.current_commit == second, "latest current commit")
  t.assert_eq(2, state.total, "latest total")
  t.assert_eq(1, dirty_count, "single committed result")
end)

t:test("search reports a missing commit without changing pages", function()
  reset_search()
  local state = new_search_state()
  state.page = 2
  local ctx = { layout = { layout_type = 4 }, state = state }
  t:patch_table(vim.ui, "input", function(_, callback)
    callback("missing")
  end)

  action.search_commit(ctx)

  t.assert_eq(1, #reports, "warning count")
  t.assert_eq('No commit matched "missing".', reports[1].message, "warning message")
  t.assert_eq(1, state.page, "applied page restored")
  t.assert_nil(fetched_page, "page fetch")
  t.assert_eq(0, dirty_count, "tabline refresh")
end)

t:test("rapid page commands preserve every requested step", function()
  reset_search()
  local state = new_search_state()
  state.total = 300
  local ctx = { layout = { layout_type = 4 }, state = state }
  local pending = {} ---@type function[]
  t:patch_table(stl.async, "run", function(callback)
    pending[#pending + 1] = callback
  end)

  action.next_page(ctx)
  action.next_page(ctx)

  t.assert_eq(3, state.page, "requested page")
  t.assert_nil(next(state.expanded), "expanded commits")
  t.assert_eq(2, #pending, "page requests")
end)

t:test("commit pane directories toggle independently and copy their displayed path", function()
  local winnr = vim.api.nvim_get_current_win() ---@type integer
  local original_bufnr = vim.api.nvim_win_get_buf(winnr) ---@type integer
  local bufnr = vim.api.nvim_create_buf(false, true) ---@type integer
  vim.api.nvim_win_set_buf(winnr, bufnr)

  local commit = { hash = "commit-a", abbrev_hash = "commit-a" }
  line_maps[bufnr] = {
    { type = "directory", commit = commit, entry = nil, filepath = "lua/era", uuid = "lua" },
  }
  local operations = {} ---@type string[]
  local copied = nil ---@type table|nil
  local ctx = {
    layout = { commits_bufnr = bufnr, commits_winnr = winnr },
    state = {
      toggle_commit_dir = function(_, hash, uuid)
        operations[#operations + 1] = "toggle:" .. hash .. ":" .. uuid
      end,
      collapse_commit_dir = function(_, hash, uuid)
        operations[#operations + 1] = "collapse:" .. hash .. ":" .. uuid
      end,
      expand_commit_dir = function(_, hash, uuid)
        operations[#operations + 1] = "expand:" .. hash .. ":" .. uuid
      end,
    },
  }
  local renders = 0
  local restore_render = t:patch_table(view, "render_commits", function()
    renders = renders + 1
  end)
  local restore_fn = t:patch_table(era, "fn", {
    select_copy_filepath = function(opts)
      copied = opts
    end,
  })

  action.select(ctx)
  action.collapse(ctx)
  action.expand(ctx)
  action.copy_filepath(ctx)

  t.assert_eq("toggle:commit-a:lua", operations[1], "select toggles directory")
  t.assert_eq("collapse:commit-a:lua", operations[2], "collapse action")
  t.assert_eq("expand:commit-a:lua", operations[3], "expand action")
  t.assert_eq(3, renders, "directory actions rerender")
  local copy_opts = assert(copied)
  t.assert_eq("/repo/lua/era", copy_opts.filepath, "displayed directory path")
  t.assert_eq("cursor", copy_opts.relative, "copy picker anchor")

  restore_fn()
  restore_render()
  vim.api.nvim_win_set_buf(winnr, original_bufnr)
  vim.api.nvim_buf_delete(bufnr, { force = true })
end)

t:test("commits keymap exposes cross-page search", function()
  local found = {} ---@type table<string, boolean>
  for _, candidate in ipairs(keymap.gen_commits({ layout = {}, state = new_search_state() })) do
    found[candidate.key] = true
  end
  t.assert_true(found["g/"], "g/ search keymap")
  t.assert_true(found.oc, "oc copy path keymap")
  t.assert_true(found.za and found.zc and found.zo, "directory fold keymaps")
end)

t:test("commits help keeps mappings with the same key in different modes", function()
  t:patch_table(keymap, "gen_commits", function()
    return { { modes = { "n" }, key = "test", desc = "normal", callback = function() end } }
  end)
  t:patch_table(keymap, "gen_filetree", function()
    return { { modes = { "x" }, key = "test", desc = "visual", callback = function() end } }
  end)
  t:patch_table(keymap, "gen_sbs", function()
    return {}
  end)

  local modes = {} ---@type table<string, boolean>
  for _, mapping in ipairs(keymap.get_help_keymaps({})) do
    for _, mode in ipairs(mapping.modes) do
      modes[mode] = true
    end
  end
  t.assert_true(modes.n, "normal mapping")
  t.assert_true(modes.x, "visual mapping")
end)

t:run()
