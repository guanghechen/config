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
---@field current                        era.m.diffview.IFileEntry
---@field entries                        era.m.diffview.IFileEntry[]
---@field refreshed_entries              era.m.diffview.IFileEntry[]
---@field token                          stl.c.CancellationToken|nil
---@field visible_entries                era.m.diffview.IFileEntry[]

---@param opts                           era.m.diffview.test.IRefreshCase
---@return era.m.diffview.view.workspace.action action
---@return fun(): era.m.diffview.IFileEntry|nil get_current
---@return era.m.diffview.IFileEntry[] opened
---@return fun(): boolean was_cleared
---@return integer changes_bufnr
---@return era.m.diffview.view.workspace.IOpenEntryOpts[] open_opts
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
  local changes_bufnr = vim.api.nvim_create_buf(false, true) ---@type integer

  t:patch_table(package.loaded, "era.m.diffview.data", {
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
    is_changes_buffer = function()
      return false
    end,
    render_changes = function()
      line_map = {}
      for _, entry in ipairs(opts.visible_entries) do
        line_map[#line_map + 1] = { type = "file", entry = entry }
      end
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
      set_current_entry = function(_, entry)
        current = entry
      end,
      set_entries = function(_, value)
        entries = value
      end,
    },
  }

  action.refresh(ctx, opts.token)
  return action,
    function()
      return current
    end,
    opened,
    function()
      return cleared
    end,
    changes_bufnr,
    open_opts
end

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
