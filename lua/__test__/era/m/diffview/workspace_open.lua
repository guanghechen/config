---@diagnostic disable: undefined-global
--- Run with: nvim -l lua/__test__/era/m/diffview/workspace_open.lua

local bootstrap = require("__test__.bootstrap")
local harness = require("__test__.harness")

local t = harness.new("era.m.diffview.workspace_open")

bootstrap.with_global(t, "stl", {
  async = {
    run = function(callback)
      callback()
    end,
  },
  reporter = {
    warn = function() end,
  },
})
bootstrap.with_global(t, "dot", {
  path = {
    workspace = function()
      return "/repo"
    end,
  },
})
bootstrap.with_global(t, "era", {})

t:test("open selects and previews the first visible file", function()
  local entries = {
    { filepath = "z-last.lua", stage_type = "unstaged", status = "M" },
    { filepath = "a-first.lua", stage_type = "staged", status = "M" },
  }
  local selected = nil ---@type era.m.diffview.IFileEntry|nil
  local previewed = nil ---@type era.m.diffview.IFileEntry|nil

  local state = {
    get_entries = function()
      return entries
    end,
    request_refresh = function(_, callback)
      callback()
    end,
    find_entry = function(_, filepath, stage_type)
      for _, entry in ipairs(entries) do
        if entry.filepath == filepath and entry.stage_type == stage_type then
          return entry
        end
      end
    end,
    set_current_entry = function(_, entry)
      selected = entry
    end,
  }

  local winnr = vim.api.nvim_get_current_win() ---@type integer
  local original_bufnr = vim.api.nvim_win_get_buf(winnr) ---@type integer
  local changes_bufnr = vim.api.nvim_create_buf(false, true) ---@type integer
  vim.api.nvim_buf_set_lines(changes_bufnr, 0, -1, false, { "Staged", "a-first.lua", "z-last.lua" })
  vim.api.nvim_win_set_buf(winnr, changes_bufnr)

  local layout = {
    tabnr = vim.api.nvim_get_current_tabpage(),
    changes_bufnr = changes_bufnr,
    changes_winnr = winnr,
  }
  local workspace_view = {
    create_layout = function()
      return layout
    end,
    set_layout = function() end,
    open_entry = function(_, entry)
      previewed = entry
    end,
  }

  t:patch_table(package.loaded, "era.m.diffview.pane.changes", {
    get_line_map = function()
      return {
        { type = "header" },
        { type = "file", entry = vim.deepcopy(entries[2]) },
        { type = "file", entry = vim.deepcopy(entries[1]) },
      }
    end,
  })
  t:patch_table(package.loaded, "era.m.diffview.view.workspace.action", {
    refresh = function() end,
  })
  t:patch_table(package.loaded, "era.m.diffview.view.workspace.keymap", {
    setup_changes = function() end,
    setup_sbs = function() end,
  })
  t:patch_table(package.loaded, "era.m.diffview.view.workspace.state", {
    active_states = {},
    create = function()
      return state
    end,
  })
  t:patch_table(package.loaded, "era.m.diffview.view.workspace.tabline", {
    register = function() end,
  })
  t:patch_table(package.loaded, "era.m.diffview.view.workspace.view", workspace_view)

  local cmd = assert(loadfile("lua/era/m/diffview/cmd.lua"))()
  cmd.__setup_git_subscription_workspace__ = function() end
  cmd.open()

  t.assert_eq(entries[2], selected, "selected entry")
  t.assert_eq(entries[2], previewed, "previewed entry")
  t.assert_eq(2, vim.api.nvim_win_get_cursor(winnr)[1], "changes cursor")

  vim.api.nvim_win_set_buf(winnr, original_bufnr)
  vim.api.nvim_buf_delete(changes_bufnr, { force = true })
end)

t:run()
