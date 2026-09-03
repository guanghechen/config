---@diagnostic disable: undefined-global
--- Run with: nvim -l lua/__test__/era/m/diffview/workspace_open.lua

local bootstrap = require("__test__.bootstrap")
local harness = require("__test__.harness")

local t = harness.new("era.m.diffview.workspace_open")
local remembered_widths = {} ---@type integer[]

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
  context = {
    diffview = {
      flag_fold_unchanges = {
        snapshot = function()
          return true
        end,
      },
      panel_width = {
        next = function(_, width)
          remembered_widths[#remembered_widths + 1] = width
        end,
      },
    },
  },
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
  local initial_fold_unchanged = nil ---@type boolean|nil
  local history_fold_unchanged = nil ---@type boolean|nil
  local history_refreshed = false
  local history_winline_setup = false

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

  local staged_winnr = vim.api.nvim_get_current_win() ---@type integer
  local original_bufnr = vim.api.nvim_win_get_buf(staged_winnr) ---@type integer
  local staged_bufnr = vim.api.nvim_create_buf(false, true) ---@type integer
  local unstaged_bufnr = vim.api.nvim_create_buf(false, true) ---@type integer
  vim.api.nvim_buf_set_lines(staged_bufnr, 0, -1, false, { "Staged", "a-first.lua" })
  vim.api.nvim_win_set_buf(staged_winnr, staged_bufnr)
  vim.cmd("belowright split")
  local unstaged_winnr = vim.api.nvim_get_current_win() ---@type integer
  vim.api.nvim_buf_set_lines(unstaged_bufnr, 0, -1, false, { "Unstaged", "z-last.lua" })
  vim.api.nvim_win_set_buf(unstaged_winnr, unstaged_bufnr)

  local layout = {
    tabnr = vim.api.nvim_get_current_tabpage(),
    history = {},
    changes = {
      staged = { stage_type = "staged", bufnr = staged_bufnr, winnr = staged_winnr },
      unstaged = { stage_type = "unstaged", bufnr = unstaged_bufnr, winnr = unstaged_winnr },
    },
  }
  local workspace_view = {
    create_layout = function()
      return layout
    end,
    set_layout = function() end,
    open_entry = function(_, entry)
      previewed = entry
    end,
    get_changes_panes = function()
      return { layout.changes.staged, layout.changes.unstaged }
    end,
    get_visible_entries = function(items)
      local visible = {} ---@type era.m.diffview.IFileEntry[]
      for _, entry in ipairs(items) do
        if entry.status ~= "?" then
          visible[#visible + 1] = entry
        end
      end
      return visible
    end,
    history_context = function(_, _, history_state)
      return { layout = layout.history, state = history_state }
    end,
  }

  t:patch_table(package.loaded, "era.m.diffview.pane.changes", {
    get_line_map = function(bufnr)
      local entry = bufnr == staged_bufnr and entries[2] or entries[1]
      return { { type = "header" }, { type = "file", entry = vim.deepcopy(entry) } }
    end,
  })
  t:patch_table(package.loaded, "era.m.diffview.view.workspace.action", {
    refresh = function() end,
  })
  t:patch_table(package.loaded, "era.m.diffview.view.workspace.keymap", {
    setup_changes = function() end,
    setup_history = function() end,
    setup_sbs = function() end,
  })
  t:patch_table(package.loaded, "era.m.diffview.view.commits.action", {
    refresh = function()
      history_refreshed = true
      return true
    end,
  })
  t:patch_table(package.loaded, "era.m.diffview.view.commits.state", {
    create = function(_, fold_unchanged)
      history_fold_unchanged = fold_unchanged
      return {
        get_commits = function()
          return {}
        end,
      }
    end,
  })
  t:patch_table(package.loaded, "era.m.diffview.view.workspace.state", {
    active_states = {},
    create = function(_, fold_unchanged)
      initial_fold_unchanged = fold_unchanged
      return state
    end,
  })
  t:patch_table(package.loaded, "era.m.diffview.view.workspace.tabline", {
    register = function() end,
  })
  t:patch_table(package.loaded, "era.m.diffview.view.workspace.winline", {
    setup = function()
      history_winline_setup = true
    end,
  })
  t:patch_table(package.loaded, "era.m.diffview.view.workspace.view", workspace_view)

  local cmd = assert(loadfile("lua/era/m/diffview/cmd.lua"))()
  cmd.__setup_git_subscription_workspace__ = function() end
  cmd.__setup_changes_resize_workspace__ = function() end
  cmd.__setup_commits_signs__ = function() end
  cmd.open()

  t.assert_eq(entries[2], selected, "selected entry")
  t.assert_eq(entries[2], previewed, "previewed entry")
  t.assert_true(initial_fold_unchanged, "global fold default forwarded")
  t.assert_true(history_fold_unchanged, "History fold default forwarded")
  t.assert_true(history_refreshed, "History refresh")
  t.assert_true(history_winline_setup, "History winline setup")
  t.assert_eq(staged_winnr, vim.api.nvim_get_current_win(), "staged focus")
  t.assert_eq(2, vim.api.nvim_win_get_cursor(staged_winnr)[1], "changes cursor")

  vim.api.nvim_win_close(unstaged_winnr, true)
  vim.api.nvim_win_set_buf(staged_winnr, original_bufnr)
  vim.api.nvim_buf_delete(staged_bufnr, { force = true })
  vim.api.nvim_buf_delete(unstaged_bufnr, { force = true })
end)

t:test("standalone log ignores the workspace embedded History state", function()
  local tabnr = vim.api.nvim_get_current_tabpage() ---@type integer
  local previous_tabtype = vim.t[tabnr].tabtype
  ---@diagnostic disable-next-line: invisible
  t:_register_cleanup(function()
    vim.t[tabnr].tabtype = previous_tabtype
  end)
  t:patch_table(stl, "e", {
    TabTypeEnum = {
      DIFFVIEW_WORKSPACE = "diffview_workspace",
      DIFFVIEW_COMMITS = "diffview_commits",
    },
  })
  t:patch_table(dot.context.diffview, "commits_layout", {
    snapshot = function()
      return 1
    end,
  })

  local layouts_created = 0
  local history_state = {
    get_path_filter = function()
      return nil
    end,
  }
  local standalone_state = {
    get_commits = function()
      return {}
    end,
  }
  t:patch_table(package.loaded, "era.m.diffview.view.commits.action", {
    refresh = function()
      return false
    end,
  })
  t:patch_table(package.loaded, "era.m.diffview.view.commits.keymap", {
    setup_commits = function() end,
    setup_filetree = function() end,
    setup_sbs = function() end,
  })
  t:patch_table(package.loaded, "era.m.diffview.view.commits.state", {
    active_states = { [tabnr] = history_state },
    create = function()
      return standalone_state
    end,
  })
  t:patch_table(package.loaded, "era.m.diffview.view.commits.tabline", {
    register = function() end,
  })
  t:patch_table(package.loaded, "era.m.diffview.view.commits.view", {
    create_layout = function()
      layouts_created = layouts_created + 1
      return { tabnr = tabnr }
    end,
    set_layout = function() end,
  })

  vim.t[tabnr].tabtype = stl.e.TabTypeEnum.DIFFVIEW_WORKSPACE
  local cmd = assert(loadfile("lua/era/m/diffview/cmd.lua"))()
  cmd.__setup_commits_signs__ = function() end
  cmd.log()

  t.assert_eq(1, layouts_created, "standalone layout created")
end)

t:test("resize watcher rerenders only when the Changes pane width changes", function()
  remembered_widths = {}
  local widths = { [42] = 40, [43] = 40 } ---@type table<integer, integer>
  local columns = 200
  local disposed = false ---@type boolean
  local callback = nil ---@type function|nil
  local autocmd_id = nil ---@type integer|nil
  local renders = 0 ---@type integer
  local ctx = {
    layout = {
      changes = {
        staged = { stage_type = "staged", winnr = 42 },
        unstaged = { stage_type = "unstaged", winnr = 43 },
      },
    },
    state = {},
  }
  local state = {
    is_disposed = function()
      return disposed
    end,
    set_resize_autocmd = function(_, value)
      autocmd_id = value
    end,
  }

  t:patch_table(vim.api, "nvim_win_is_valid", function(winnr)
    return widths[winnr] ~= nil
  end)
  t:patch_table(vim.api, "nvim_win_get_width", function(winnr)
    return widths[winnr]
  end)
  local get_option_value = vim.api.nvim_get_option_value
  t:patch_table(vim.api, "nvim_get_option_value", function(name, opts)
    if name == "columns" then
      return columns
    end
    return get_option_value(name, opts)
  end)
  t:patch_table(vim.api, "nvim_create_autocmd", function(event, opts)
    t.assert_eq("WinResized", event, "resize event")
    callback = opts.callback
    return 77
  end)
  t:patch_table(package.loaded, "era.m.diffview.view.workspace.view", {
    get_changes_panes = function()
      return { ctx.layout.changes.staged, ctx.layout.changes.unstaged }
    end,
    render_changes = function(actual_ctx)
      t.assert_eq(ctx, actual_ctx, "render context")
      renders = renders + 1
    end,
  })

  local cmd = assert(loadfile("lua/era/m/diffview/cmd.lua"))()
  cmd.__setup_changes_resize_workspace__(state, ctx)
  t.assert_eq(77, autocmd_id, "owned autocmd")
  local resize = assert(callback)

  resize()
  t.assert_eq(0, renders, "same width")
  widths[42] = 5
  widths[43] = 5
  resize()
  resize()
  t.assert_eq(1, renders, "narrow width")
  t.assert_eq(1, #remembered_widths, "manual resize writes")
  t.assert_eq(5, remembered_widths[1], "remembered manual width")

  columns = 240
  widths[42] = 40
  widths[43] = 40
  resize()
  t.assert_eq(2, renders, "restored width")
  t.assert_eq(1, #remembered_widths, "terminal resize does not write")

  ctx.layout.changes.staged.winnr = 44
  ctx.layout.changes.unstaged.winnr = 45
  widths[44] = 24
  widths[45] = 24
  resize()
  t.assert_eq(3, renders, "recreated panes render")
  t.assert_eq(1, #remembered_widths, "recreated panes do not overwrite the preference")

  widths[44] = 18
  widths[45] = 18
  resize()
  t.assert_eq(4, renders, "recreated pane resize")
  t.assert_eq(2, #remembered_widths, "recreated pane manual resize writes")
  t.assert_eq(18, remembered_widths[2], "recreated pane width")

  disposed = true
  widths[44] = 10
  widths[45] = 10
  resize()
  t.assert_eq(4, renders, "disposed state")
end)

t:run()
