---@diagnostic disable: undefined-global
--- Run with: nvim -l lua/__test__/era/m/diffview/workspace_navigation.lua

local bootstrap = require("__test__.bootstrap")
local harness = require("__test__.harness")

local t = harness.new("era.m.diffview.workspace_navigation")

bootstrap.with_global(t, "stl", {
  async = {
    run = function(callback)
      callback()
    end,
  },
})
bootstrap.with_global(t, "dot", {})
bootstrap.with_global(t, "era", {})

---@param line_map                      table[]|nil
---@param opened                        era.m.diffview.IFileEntry[]
---@param ordered_entries               era.m.diffview.IFileEntry[]|nil
---@return era.m.diffview.view.workspace.action
local function load_action(line_map, opened, ordered_entries)
  t:patch_table(package.loaded, "era.m.diffview.data", {})
  t:patch_table(package.loaded, "era.m.diffview.pane.changes", {
    find_entry_line = function(items, target)
      for i, item in ipairs(items) do
        local entry = item.entry
        if
          item.type == "file"
          and entry
          and entry.filepath == target.filepath
          and entry.stage_type == target.stage_type
        then
          return i
        end
      end
    end,
    get_line_map = function()
      return line_map
    end,
    get_entries_in_render_order = function(entries)
      return ordered_entries or entries
    end,
  })
  t:patch_table(package.loaded, "era.m.diffview.pane.sbs", {})
  t:patch_table(package.loaded, "era.m.diffview.view.workspace.state", {})
  t:patch_table(package.loaded, "era.m.diffview.view.workspace.view", {
    open_entry = function(_, entry)
      opened[#opened + 1] = entry
    end,
  })
  return assert(loadfile("lua/era/m/diffview/view/workspace/action.lua"))()
end

t:test("changes panel order groups stages and follows filetree traversal", function()
  t:patch_table(package.loaded, "era.m.diffview.config", { NS = 0 })
  local changes = assert(loadfile("lua/era/m/diffview/pane/changes.lua"))()
  local unstaged = { filepath = "a.lua", stage_type = "unstaged", status = "M" }
  local staged_root = { filepath = "z.lua", stage_type = "staged", status = "M" }
  local staged_nested = { filepath = "dir/a.lua", stage_type = "staged", status = "M" }

  local ordered = changes.get_entries_in_render_order({ unstaged, staged_root, staged_nested })

  t.assert_eq(staged_nested, ordered[1], "nested staged entry")
  t.assert_eq(staged_root, ordered[2], "root staged entry")
  t.assert_eq(unstaged, ordered[3], "unstaged entry")
end)

t:test("cross-pane navigation follows visible changes order and wraps", function()
  local hidden = { filepath = "hidden.lua", stage_type = "unstaged", status = "M" }
  local beta = { filepath = "b.lua", stage_type = "unstaged", status = "M" }
  local alpha = { filepath = "a.lua", stage_type = "staged", status = "M" }
  local entries = { hidden, beta, alpha }
  local current = alpha
  local opened = {} ---@type era.m.diffview.IFileEntry[]
  local line_map = {
    { type = "header" },
    { type = "file", entry = alpha },
    { type = "directory", uuid = "collapsed" },
    { type = "file", entry = beta },
  }
  local action = load_action(line_map, opened, { alpha, hidden, beta })

  local winnr = vim.api.nvim_get_current_win() ---@type integer
  local original_bufnr = vim.api.nvim_win_get_buf(winnr) ---@type integer
  local changes_bufnr = vim.api.nvim_create_buf(false, true) ---@type integer
  vim.api.nvim_buf_set_lines(changes_bufnr, 0, -1, false, { "Staged", "a.lua", "collapsed", "b.lua" })
  vim.api.nvim_win_set_buf(winnr, changes_bufnr)
  local ctx = {
    layout = { changes_bufnr = changes_bufnr, changes_winnr = winnr },
    state = {
      get_entries = function()
        return entries
      end,
      get_current_entry = function()
        return current
      end,
      set_current_entry = function(_, entry)
        current = entry
      end,
    },
  }

  action.goto_next_entry(ctx)
  t.assert_eq(beta, current, "next visible entry")
  t.assert_eq(4, vim.api.nvim_win_get_cursor(winnr)[1], "next cursor")

  action.goto_next_entry(ctx)
  t.assert_eq(alpha, current, "next wraps")
  t.assert_eq(2, vim.api.nvim_win_get_cursor(winnr)[1], "wrapped cursor")

  action.goto_prev_entry(ctx)
  t.assert_eq(beta, current, "previous wraps")
  t.assert_eq(3, #opened, "preview count")
  t.assert_eq(beta, opened[3], "previous preview")

  vim.api.nvim_win_set_buf(winnr, original_bufnr)
  vim.api.nvim_buf_delete(changes_bufnr, { force = true })
end)

t:test("navigation skips hidden current entry without losing direction", function()
  local before = { filepath = "a.lua", stage_type = "unstaged", status = "M" }
  local hidden = { filepath = "middle/hidden.lua", stage_type = "unstaged", status = "M" }
  local after = { filepath = "z.lua", stage_type = "unstaged", status = "M" }
  local entries = { after, hidden, before }
  local current = hidden
  local opened = {} ---@type era.m.diffview.IFileEntry[]
  local line_map = {
    { type = "header" },
    { type = "file", entry = before },
    { type = "directory", uuid = "middle" },
    { type = "file", entry = after },
  }
  local action = load_action(line_map, opened, { before, hidden, after })
  local changes_bufnr = vim.api.nvim_create_buf(false, true) ---@type integer
  local ctx = {
    layout = { changes_bufnr = changes_bufnr },
    state = {
      get_entries = function()
        return entries
      end,
      get_current_entry = function()
        return current
      end,
      set_current_entry = function(_, entry)
        current = entry
      end,
    },
  }

  action.goto_next_entry(ctx)
  t.assert_eq(after, current, "next visible entry after hidden current")

  current = hidden
  action.goto_prev_entry(ctx)
  t.assert_eq(before, current, "previous visible entry before hidden current")
  t.assert_eq(2, #opened, "preview count")

  vim.api.nvim_buf_delete(changes_bufnr, { force = true })
end)

t:test("navigation does not enter entries hidden by the rendered panel", function()
  local hidden = { filepath = "hidden.lua", stage_type = "unstaged", status = "M" }
  local opened = {} ---@type era.m.diffview.IFileEntry[]
  local action = load_action({ { type = "header" }, { type = "directory", uuid = "collapsed" } }, opened)
  local changes_bufnr = vim.api.nvim_create_buf(false, true) ---@type integer
  local current = hidden
  local ctx = {
    layout = { changes_bufnr = changes_bufnr },
    state = {
      get_entries = function()
        return { hidden }
      end,
      get_current_entry = function()
        return current
      end,
      set_current_entry = function(_, entry)
        current = entry
      end,
    },
  }

  action.goto_next_entry(ctx)
  t.assert_eq(hidden, current, "selection unchanged")
  t.assert_eq(0, #opened, "no hidden preview")

  vim.api.nvim_buf_delete(changes_bufnr, { force = true })
end)

t:test("navigation falls back to state order without a changes panel", function()
  local alpha = { filepath = "a.lua", stage_type = "staged", status = "M" }
  local beta = { filepath = "b.lua", stage_type = "unstaged", status = "M" }
  local entries = { alpha, beta }
  local current = alpha
  local opened = {} ---@type era.m.diffview.IFileEntry[]
  local action = load_action(nil, opened)
  local ctx = {
    layout = {},
    state = {
      get_entries = function()
        return entries
      end,
      get_current_entry = function()
        return current
      end,
      set_current_entry = function(_, entry)
        current = entry
      end,
    },
  }

  action.goto_next_entry(ctx)
  t.assert_eq(beta, current, "fallback next")
  action.goto_prev_entry(ctx)
  t.assert_eq(alpha, current, "fallback previous")
  t.assert_eq(2, #opened, "fallback previews")
end)

t:run()
