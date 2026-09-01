---@diagnostic disable: undefined-global
--- Run with: nvim -l lua/__test__/era/m/diffview/workspace_refresh.lua

local bootstrap = require("__test__.bootstrap")
local CancellationToken = require("stl.c.cancellation_token")
local harness = require("__test__.harness")

local t = harness.new("era.m.diffview.workspace_refresh")

bootstrap.with_global(t, "stl", {
  async = {
    scheduler = function() end,
  },
})
bootstrap.with_global(t, "dot", {
  state = {
    status = {
      dirtier_tabline = {
        mark_dirty = function() end,
      },
    },
  },
})
bootstrap.with_global(t, "era", {})
t:patch_table(package.loaded, "era.m.diffview.util", {
  workspace_path = function(filepath)
    return "/repo/" .. filepath
  end,
})

---@class era.m.diffview.test.IRefreshCase
---@field current                        era.m.diffview.IFileEntry|nil
---@field clear_failures                 integer|nil
---@field defer_refresh                  boolean|nil
---@field entries                        era.m.diffview.IFileEntry[]
---@field render_failures                integer|nil
---@field refreshed_entries              era.m.diffview.IFileEntry[]
---@field snapshot_initialized            boolean|nil
---@field snapshot_unchanged              boolean|nil
---@field token                          stl.c.CancellationToken|nil
---@field visible_entries                era.m.diffview.IFileEntry[]

---@param opts                           era.m.diffview.test.IRefreshCase
---@return era.m.diffview.view.workspace.action action
---@return fun(): era.m.diffview.IFileEntry|nil get_current
---@return era.m.diffview.IFileEntry[] opened
---@return fun(): boolean was_cleared
---@return integer changes_bufnr
---@return era.m.diffview.view.workspace.IOpenEntryOpts[] open_opts
---@return fun(): integer get_set_count
---@return fun(): integer get_render_count
---@return fun(): nil run_refresh
---@return fun(): integer get_commit_count
---@return fun(): integer get_height_sync_count
local function load_refresh_case(opts)
  local current = opts.current ---@type era.m.diffview.IFileEntry|nil
  local entries = opts.entries
  local line_map = {} ---@type table[]
  for _, entry in ipairs(opts.entries) do
    line_map[#line_map + 1] = { type = "file", entry = entry }
  end

  local opened = {} ---@type era.m.diffview.IFileEntry[]
  local open_opts = {} ---@type era.m.diffview.view.workspace.IOpenEntryOpts[]
  local cleared = false
  local clear_failures = opts.clear_failures or 0
  local commit_count = 0 ---@type integer
  local height_sync_count = 0 ---@type integer
  local render_count = 0 ---@type integer
  local render_failures = opts.render_failures or 0
  local set_count = 0 ---@type integer
  local snapshot_applied = opts.snapshot_initialized ~= false
  local changes_bufnr = vim.api.nvim_create_buf(false, true) ---@type integer

  t:patch_table(package.loaded, "era.m.diffview.data", {
    equal_diff_entries = function()
      return opts.snapshot_unchanged == true
    end,
    fetch_diff_entries = function()
      return opts.refreshed_entries
    end,
  })
  t:patch_table(package.loaded, "era.m.diffview.pane.changes", {
    find_entry_line = function()
      return nil
    end,
    get_entries_in_render_order = function(items)
      return items
    end,
    get_line_map = function()
      return line_map
    end,
  })
  t:patch_table(package.loaded, "era.m.diffview.pane.sbs", {})
  t:patch_table(package.loaded, "era.m.diffview.view.workspace.state", {})
  t:patch_table(package.loaded, "era.m.diffview.view.workspace.view", {
    clear_sbs = function()
      if clear_failures > 0 then
        clear_failures = clear_failures - 1
        error("injected clear failure")
      end
      cleared = true
    end,
    open_entry = function(_, entry, _, entry_opts)
      opened[#opened + 1] = entry
      open_opts[#open_opts + 1] = entry_opts
    end,
    focus_changes = function() end,
    get_changes_pane = function(_, stage_type)
      return { stage_type = stage_type, bufnr = changes_bufnr }
    end,
    get_changes_panes = function()
      return { { bufnr = changes_bufnr } }
    end,
    get_visible_entries = function(items)
      return items
    end,
    is_changes_buffer = function()
      return false
    end,
    render_changes = function()
      render_count = render_count + 1
      if render_failures > 0 then
        render_failures = render_failures - 1
        error("injected render failure")
      end
      line_map = {}
      for _, entry in ipairs(opts.visible_entries) do
        line_map[#line_map + 1] = { type = "file", entry = entry }
      end
    end,
    sync_changes_heights = function()
      height_sync_count = height_sync_count + 1
    end,
  })

  local action = assert(loadfile("lua/era/m/diffview/view/workspace/action.lua"))()
  local ctx = {
    layout = { changes_bufnr = changes_bufnr },
    state = {
      get_current_entry = function()
        return current
      end,
      get_entries = function()
        return entries
      end,
      commit_entries_snapshot = function()
        commit_count = commit_count + 1
        snapshot_applied = true
      end,
      is_entries_snapshot_applied = function()
        return snapshot_applied
      end,
      set_current_entry = function(_, entry)
        current = entry
      end,
      set_entries = function(_, value)
        set_count = set_count + 1
        entries = value
        snapshot_applied = false
      end,
    },
  }

  local function run_refresh()
    action.refresh(ctx, opts.token)
  end
  if not opts.defer_refresh then
    run_refresh()
  end
  return action,
    function()
      return current
    end,
    opened,
    function()
      return cleared
    end,
    changes_bufnr,
    open_opts,
    function()
      return set_count
    end,
    function()
      return render_count
    end,
    run_refresh,
    function()
      return commit_count
    end,
    function()
      return height_sync_count
    end
end

t:test("refresh commits and renders the initial empty snapshot", function()
  local _, get_current, opened, was_cleared, bufnr, _, get_set_count, get_render_count, _, get_commit_count =
    load_refresh_case({
      current = nil,
      entries = {},
      refreshed_entries = {},
      snapshot_initialized = false,
      snapshot_unchanged = true,
      visible_entries = {},
    })

  t.assert_nil(get_current(), "selection remains empty")
  t.assert_eq(0, #opened, "no preview opened")
  t.assert_eq(1, get_set_count(), "initial snapshot committed")
  t.assert_eq(1, get_render_count(), "empty pane headers rendered")
  t.assert_eq(1, get_commit_count(), "initial snapshot marked applied")
  t.assert_false(was_cleared(), "already empty preview not rewritten")
  vim.api.nvim_buf_delete(bufnr, { force = true })
end)

t:test("refresh skips an unchanged panel snapshot but refreshes the selected preview", function()
  local current = {
    filepath = "a.lua",
    stage_type = "unstaged",
    status = "M",
    insertions = 1,
    deletions = 2,
  }
  local refreshed = vim.deepcopy(current)
  local _, get_current, opened, was_cleared, bufnr, open_opts, get_set_count, get_render_count, _, get_commit_count, get_height_sync_count =
    load_refresh_case({
      current = current,
      entries = { current },
      refreshed_entries = { refreshed },
      snapshot_unchanged = true,
      visible_entries = { current },
    })

  t.assert_true(get_current() == current, "existing canonical selection retained")
  t.assert_true(opened[1] == current, "selected preview refreshed from existing snapshot")
  t.assert_true(open_opts[1].preserve_view, "same preview preserves view")
  t.assert_eq(0, get_set_count(), "state snapshot not replaced")
  t.assert_eq(0, get_render_count(), "Changes panes not rendered")
  t.assert_eq(0, get_commit_count(), "already applied snapshot not recommitted")
  t.assert_eq(1, get_height_sync_count(), "cheap pane height invariant synchronized")
  t.assert_false(was_cleared(), "preview retained")
  vim.api.nvim_buf_delete(bufnr, { force = true })
end)

t:test("failed render keeps the snapshot pending so an identical retry completes", function()
  local current = { filepath = "a.lua", stage_type = "unstaged", status = "M", insertions = 1 }
  local refreshed = { filepath = "a.lua", stage_type = "unstaged", status = "M", insertions = 2 }
  local _, get_current, opened, _, bufnr, _, get_set_count, get_render_count, run_refresh, get_commit_count =
    load_refresh_case({
      current = current,
      defer_refresh = true,
      entries = { current },
      refreshed_entries = { refreshed },
      render_failures = 1,
      visible_entries = { refreshed },
    })

  local ok = pcall(run_refresh)
  t.assert_false(ok, "injected render failure propagated")
  t.assert_eq(0, get_commit_count(), "failed snapshot remains pending")

  run_refresh()
  t.assert_eq(refreshed, get_current(), "retry commits canonical selection")
  t.assert_eq(refreshed, opened[1], "retry opens refreshed preview")
  t.assert_eq(2, get_set_count(), "identical retry still takes slow path")
  t.assert_eq(2, get_render_count(), "failed render retried")
  t.assert_eq(1, get_commit_count(), "retry marks snapshot applied")
  vim.api.nvim_buf_delete(bufnr, { force = true })
end)

t:test("failed preview cleanup preserves selection until an identical retry completes", function()
  local removed = { filepath = "a.lua", stage_type = "unstaged", status = "M" }
  local _, get_current, _, was_cleared, bufnr, _, get_set_count, get_render_count, run_refresh, get_commit_count =
    load_refresh_case({
      clear_failures = 1,
      current = removed,
      defer_refresh = true,
      entries = { removed },
      refreshed_entries = {},
      visible_entries = {},
    })

  local ok = pcall(run_refresh)
  t.assert_false(ok, "injected cleanup failure propagated")
  t.assert_eq(removed, get_current(), "failed cleanup keeps prior selection for retry")
  t.assert_eq(0, get_commit_count(), "failed snapshot remains pending")

  run_refresh()
  t.assert_nil(get_current(), "retry clears selection")
  t.assert_true(was_cleared(), "retry completes preview cleanup")
  t.assert_eq(2, get_set_count(), "identical retry still takes slow path")
  t.assert_eq(2, get_render_count(), "retry restores panel application")
  t.assert_eq(1, get_commit_count(), "retry marks snapshot applied")
  vim.api.nvim_buf_delete(bufnr, { force = true })
end)

t:test("refresh rebinds selection to the canonical entry", function()
  local stale = { filepath = "a.lua", stage_type = "unstaged", status = "M", insertions = 1 }
  local refreshed = { filepath = "a.lua", stage_type = "unstaged", status = "M", insertions = 2 }
  local _, get_current, opened, was_cleared, bufnr, open_opts = load_refresh_case({
    current = stale,
    entries = { stale },
    refreshed_entries = { refreshed },
    visible_entries = { refreshed },
  })

  t.assert_eq(refreshed, get_current(), "canonical selection")
  t.assert_eq(refreshed, opened[1], "canonical preview")
  t.assert_true(open_opts[1].preserve_view, "same entry preserves view")
  t.assert_false(was_cleared(), "preview retained")
  vim.api.nvim_buf_delete(bufnr, { force = true })
end)

t:test("refresh follows a file across stage transition", function()
  local unstaged = { filepath = "a.lua", stage_type = "unstaged", status = "M" }
  local staged = { filepath = "a.lua", stage_type = "staged", status = "M" }
  local _, get_current, opened, _, bufnr, open_opts = load_refresh_case({
    current = unstaged,
    entries = { unstaged },
    refreshed_entries = { staged },
    visible_entries = { staged },
  })

  t.assert_eq(staged, get_current(), "staged counterpart")
  t.assert_eq(staged, opened[1], "staged preview")
  t.assert_false(open_opts[1].preserve_view, "stage transition replaces view")
  vim.api.nvim_buf_delete(bufnr, { force = true })
end)

t:test("refresh selects the next visible entry when current disappears", function()
  local alpha = { filepath = "a.lua", stage_type = "unstaged", status = "M" }
  local removed = { filepath = "b.lua", stage_type = "unstaged", status = "M" }
  local charlie = { filepath = "c.lua", stage_type = "unstaged", status = "M" }
  local _, get_current, opened, _, bufnr = load_refresh_case({
    current = removed,
    entries = { alpha, removed, charlie },
    refreshed_entries = { alpha, charlie },
    visible_entries = { alpha, charlie },
  })

  t.assert_eq(charlie, get_current(), "next selection")
  t.assert_eq(charlie, opened[1], "next preview")
  vim.api.nvim_buf_delete(bufnr, { force = true })
end)

t:test("refresh falls back to the previous visible entry", function()
  local alpha = { filepath = "a.lua", stage_type = "unstaged", status = "M" }
  local removed = { filepath = "b.lua", stage_type = "unstaged", status = "M" }
  local _, get_current, opened, _, bufnr = load_refresh_case({
    current = removed,
    entries = { alpha, removed },
    refreshed_entries = { alpha },
    visible_entries = { alpha },
  })

  t.assert_eq(alpha, get_current(), "previous selection")
  t.assert_eq(alpha, opened[1], "previous preview")
  vim.api.nvim_buf_delete(bufnr, { force = true })
end)

t:test("refresh clears selection and preview when no entries remain", function()
  local removed = { filepath = "a.lua", stage_type = "unstaged", status = "M" }
  local _, get_current, opened, was_cleared, bufnr = load_refresh_case({
    current = removed,
    entries = { removed },
    refreshed_entries = {},
    visible_entries = {},
  })

  t.assert_nil(get_current(), "cleared selection")
  t.assert_eq(0, #opened, "no preview")
  t.assert_true(was_cleared(), "preview cleared")
  vim.api.nvim_buf_delete(bufnr, { force = true })
end)

t:test("cancelled refresh does not write disposed view state", function()
  local current = { filepath = "a.lua", stage_type = "unstaged", status = "M" }
  local refreshed = { filepath = "a.lua", stage_type = "staged", status = "M" }
  local token = CancellationToken.new()
  token:cancel()
  local _, get_current, opened, was_cleared, bufnr = load_refresh_case({
    current = current,
    entries = { current },
    refreshed_entries = { refreshed },
    token = token,
    visible_entries = { refreshed },
  })

  t.assert_eq(current, get_current(), "selection unchanged")
  t.assert_eq(0, #opened, "preview unchanged")
  t.assert_false(was_cleared(), "preview not cleared")
  vim.api.nvim_buf_delete(bufnr, { force = true })
end)

t:run()
