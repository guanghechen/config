local bootstrap = require("__test__.support.bootstrap")
local harness = require("__test__.support.harness")

local t = harness.new()
local requested_tree_focus

local workspace = "/repo"
t:patch_table(package.loaded, "era.m.diffview.util", {
  workspace_path = function(filepath)
    return workspace .. "/" .. filepath
  end,
})

bootstrap.with_global(t, "stl", {
  async = {
    run = function(callback)
      callback()
    end,
  },
  e = { TabTypeEnum = { NORMAL = "normal" } },
  reporter = { warn = function() end },
})
bootstrap.with_global(t, "dot", {})
bootstrap.with_global(t, "era", {})

---@alias era.m.diffview.test.LineMapProvider fun(bufnr: integer): table[]|nil

---@param line_map                      table[]|era.m.diffview.test.LineMapProvider|nil
---@param opened                        era.m.diffview.IFileEntry[]
---@param ordered_entries               era.m.diffview.IFileEntry[]|nil
---@return era.m.diffview.view.workspace.action
local function load_action(line_map, opened, ordered_entries)
  local pane = require("__test__.support.diffview_pane").new(function(bufnr)
    if type(line_map) == "function" then
      return line_map(bufnr)
    end
    return line_map
  end)
  pane.get_entries_in_render_order = function(entries)
    return ordered_entries or entries
  end
  t:patch_table(package.loaded, "era.m.diffview.pane.changes", pane)
  t:patch_table(package.loaded, "era.m.diffview.pane.sbs", {})
  t:patch_table(package.loaded, "era.m.diffview.view.workspace.view", {
    focus_changes = function(lyt, stage_type)
      local pane = lyt.changes[stage_type]
      if pane.winnr and vim.api.nvim_win_is_valid(pane.winnr) then
        vim.api.nvim_set_current_win(pane.winnr)
      end
    end,
    get_changes_pane = function(lyt, stage_type)
      return lyt.changes[stage_type]
    end,
    get_changes_panes = function(lyt)
      if not lyt.changes then
        return {}
      end
      return { lyt.changes.staged, lyt.changes.unstaged }
    end,
    get_visible_entries = function(entries)
      return entries
    end,
    hide_changes = function(lyt)
      lyt.changes_hidden = true
    end,
    is_changes_buffer = function(lyt, bufnr)
      if not lyt.changes then
        return false
      end
      return lyt.changes.staged.bufnr == bufnr or lyt.changes.unstaged.bufnr == bufnr
    end,
    open_entry = function(_, entry)
      opened[#opened + 1] = entry
    end,
    render_changes = function() end,
    show_changes = function(lyt)
      lyt.changes_hidden = false
    end,
  })
  return assert(loadfile("lua/era/m/diffview/view/workspace/action.lua"))()
end

t:test("changes panel order groups stages and follows filetree traversal", function()
  t:patch_table(package.loaded, "era.m.diffview.config", { NS = 0 })
  t:patch_table(package.loaded, "era.m.diffview.util", {
    get_status_hlgroup = function()
      return "m_dv_ft_filename"
    end,
  })
  local changes = assert(loadfile("lua/era/m/diffview/pane/changes.lua"))()
  local unstaged = { filepath = "a.lua", stage_type = "unstaged", status = "M" }
  local staged_root = { filepath = "z.lua", stage_type = "staged", status = "M" }
  local staged_nested = { filepath = "dir/a.lua", stage_type = "staged", status = "M" }

  local ordered = changes.get_entries_in_render_order({ unstaged, staged_root, staged_nested })

  t.assert_eq(staged_nested, ordered[1], "nested staged entry")
  t.assert_eq(staged_root, ordered[2], "root staged entry")
  t.assert_eq(unstaged, ordered[3], "unstaged entry")
end)

t:test("hiding untracked files selects the first remaining rendered entry", function()
  local show_untracked = true
  local dirty = 0
  t:patch_table(dot, "context", {
    diffview = {
      flag_untracked = {
        snapshot = function()
          return show_untracked
        end,
        next = function(_, value)
          show_untracked = value
        end,
      },
    },
  })
  t:patch_table(dot, "state", {
    status = {
      dirtier_tabline = {
        mark_dirty = function()
          dirty = dirty + 1
        end,
      },
    },
  })

  local untracked = { filepath = "new.lua", stage_type = "unstaged", status = "?" }
  local hidden = { filepath = "hidden.lua", stage_type = "unstaged", status = "M" }
  local tracked = { filepath = "tracked.lua", stage_type = "unstaged", status = "M" }
  local entries = { untracked, hidden, tracked }
  local current = untracked
  local opened = {} ---@type era.m.diffview.IFileEntry[]
  local action = load_action(
    { { type = "directory" }, { type = "file", entry = tracked } },
    opened,
    { hidden, tracked }
  )
  local view = package.loaded["era.m.diffview.view.workspace.view"]
  view.get_visible_entries = function(items)
    local visible = {} ---@type era.m.diffview.IFileEntry[]
    for _, entry in ipairs(items) do
      if show_untracked or entry.status ~= "?" then
        visible[#visible + 1] = entry
      end
    end
    return visible
  end
  local ctx = require("__test__.support.diffview").workspace_context({
    layout = {
      changes = {
        staged = { stage_type = "staged" },
        unstaged = { stage_type = "unstaged", bufnr = vim.api.nvim_get_current_buf() },
      },
    },
    state = {
      get_tree = function()
        return {
          focus_key = function(_, key)
            requested_tree_focus = key
          end,
        }
      end,
      get_current_entry = function()
        return current
      end,
      get_entries = function()
        return entries
      end,
      set_current_entry = function(_, entry)
        current = entry
      end,
    },
  })

  action.toggle_untracked(ctx)

  t.assert_false(show_untracked, "untracked visibility")
  t.assert_eq(tracked, current, "remaining selection")
  t.assert_eq(tracked, opened[1], "remaining preview")
  t.assert_eq(1, dirty, "tabline dirtied")
end)

t:test("cross-pane navigation follows visible changes order and wraps", function()
  local hidden = { filepath = "hidden.lua", stage_type = "unstaged", status = "M" }
  local beta = { filepath = "b.lua", stage_type = "unstaged", status = "M" }
  local alpha = { filepath = "a.lua", stage_type = "staged", status = "M" }
  local entries = { hidden, beta, alpha }
  local current = alpha
  local opened = {} ---@type era.m.diffview.IFileEntry[]
  local staged_winnr = vim.api.nvim_get_current_win() ---@type integer
  local original_bufnr = vim.api.nvim_win_get_buf(staged_winnr) ---@type integer
  local staged_bufnr = vim.api.nvim_create_buf(false, true) ---@type integer
  local unstaged_bufnr = vim.api.nvim_create_buf(false, true) ---@type integer
  vim.api.nvim_buf_set_lines(staged_bufnr, 0, -1, false, { "Staged", "a.lua" })
  vim.api.nvim_win_set_buf(staged_winnr, staged_bufnr)
  vim.cmd("belowright split")
  local unstaged_winnr = vim.api.nvim_get_current_win() ---@type integer
  vim.api.nvim_buf_set_lines(unstaged_bufnr, 0, -1, false, { "Unstaged", "collapsed", "b.lua" })
  vim.api.nvim_win_set_buf(unstaged_winnr, unstaged_bufnr)
  vim.api.nvim_set_current_win(staged_winnr)
  local action = load_action(function(bufnr)
    if bufnr == staged_bufnr then
      return { { type = "header" }, { type = "file", entry = alpha } }
    end
    return {
      { type = "header" },
      { type = "directory", uuid = "collapsed" },
      { type = "file", entry = beta },
    }
  end, opened, { alpha, hidden, beta })

  local ctx = require("__test__.support.diffview").workspace_context({
    layout = {
      changes = {
        staged = { stage_type = "staged", bufnr = staged_bufnr, winnr = staged_winnr },
        unstaged = { stage_type = "unstaged", bufnr = unstaged_bufnr, winnr = unstaged_winnr },
      },
    },
    state = {
      get_tree = function()
        return {
          focus_key = function(_, key)
            requested_tree_focus = key
          end,
        }
      end,
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
  })

  action.goto_next_entry(ctx)
  t.assert_eq(beta, current, "next visible entry")
  t.assert_eq(unstaged_winnr, vim.api.nvim_get_current_win(), "next pane")
  t.assert_eq(
    require("era.m.diffview.pane.tree").key(nil, beta.filepath, false),
    requested_tree_focus,
    "next cursor identity"
  )

  action.goto_next_entry(ctx)
  t.assert_eq(alpha, current, "next wraps")
  t.assert_eq(staged_winnr, vim.api.nvim_get_current_win(), "wrapped pane")
  t.assert_eq(
    require("era.m.diffview.pane.tree").key(nil, alpha.filepath, false),
    requested_tree_focus,
    "wrapped cursor identity"
  )

  action.goto_prev_entry(ctx)
  t.assert_eq(beta, current, "previous wraps")
  t.assert_eq(3, #opened, "preview count")
  t.assert_eq(beta, opened[3], "previous preview")

  vim.api.nvim_win_close(unstaged_winnr, true)
  vim.api.nvim_win_set_buf(staged_winnr, original_bufnr)
  vim.api.nvim_buf_delete(staged_bufnr, { force = true })
  vim.api.nvim_buf_delete(unstaged_bufnr, { force = true })
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
  local ctx = require("__test__.support.diffview").workspace_context({
    layout = {
      changes = {
        staged = { stage_type = "staged" },
        unstaged = { stage_type = "unstaged", bufnr = changes_bufnr },
      },
    },
    state = {
      get_tree = function()
        return {
          focus_key = function(_, key)
            requested_tree_focus = key
          end,
        }
      end,
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
  })

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
  local ctx = require("__test__.support.diffview").workspace_context({
    layout = {
      changes = {
        staged = { stage_type = "staged" },
        unstaged = { stage_type = "unstaged", bufnr = changes_bufnr },
      },
    },
    state = {
      get_tree = function()
        return {
          focus_key = function(_, key)
            requested_tree_focus = key
          end,
        }
      end,
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
  })

  action.goto_next_entry(ctx)
  t.assert_eq(hidden, current, "selection unchanged")
  t.assert_eq(0, #opened, "no hidden preview")

  vim.api.nvim_buf_delete(changes_bufnr, { force = true })
end)

t:test("reveal expands hidden entry ancestors, focuses the entry, then hides Changes", function()
  local current = { filepath = "middle/hidden.lua", stage_type = "unstaged", status = "M" }
  local collapsed = true
  local sbs_winnr = vim.api.nvim_get_current_win() ---@type integer
  local original_bufnr = vim.api.nvim_win_get_buf(sbs_winnr) ---@type integer
  local changes_bufnr = vim.api.nvim_create_buf(false, true) ---@type integer
  vim.api.nvim_buf_set_lines(changes_bufnr, 0, -1, false, { "Unstaged", "hidden.lua" })
  vim.cmd("belowright split")
  local changes_winnr = vim.api.nvim_get_current_win() ---@type integer
  vim.api.nvim_win_set_buf(changes_winnr, changes_bufnr)
  vim.api.nvim_set_current_win(sbs_winnr)

  local action = load_action(function()
    if collapsed then
      return { { type = "header" }, { type = "directory", uuid = "middle" } }
    end
    return { { type = "header" }, { type = "file", entry = current } }
  end, {})
  local lyt = {
    changes = {
      staged = { stage_type = "staged" },
      unstaged = { stage_type = "unstaged", bufnr = changes_bufnr, winnr = changes_winnr },
    },
  }
  local ctx = require("__test__.support.diffview").workspace_context({
    layout = lyt,
    state = {
      get_tree = function()
        return {
          focus_key = function(_, key)
            requested_tree_focus = key
          end,
        }
      end,
      expand_dir = function(_, stage_type, dir)
        t.assert_eq("unstaged", stage_type, "expanded stage")
        t.assert_eq("middle", dir, "expanded ancestor")
        collapsed = false
      end,
      get_current_entry = function()
        return current
      end,
    },
  })

  action.reveal(ctx)
  t.assert_false(collapsed, "ancestor expanded")
  t.assert_eq(changes_winnr, vim.api.nvim_get_current_win(), "Changes focused")
  t.assert_eq(
    require("era.m.diffview.pane.tree").key(nil, current.filepath, false),
    requested_tree_focus,
    "entry cursor identity"
  )

  action.reveal(ctx)
  t.assert_true(lyt.changes_hidden, "Changes hidden")

  vim.api.nvim_win_close(changes_winnr, true)
  vim.api.nvim_win_set_buf(sbs_winnr, original_bufnr)
  vim.api.nvim_buf_delete(changes_bufnr, { force = true })
end)

t:test("navigation falls back to state order without a changes panel", function()
  local alpha = { filepath = "a.lua", stage_type = "staged", status = "M" }
  local beta = { filepath = "b.lua", stage_type = "unstaged", status = "M" }
  local entries = { alpha, beta }
  local current = alpha
  local opened = {} ---@type era.m.diffview.IFileEntry[]
  local action = load_action(nil, opened)
  local ctx = require("__test__.support.diffview").workspace_context({
    layout = {
      changes = {
        staged = { stage_type = "staged" },
        unstaged = { stage_type = "unstaged" },
      },
    },
    state = {
      get_tree = function()
        return {
          focus_key = function(_, key)
            requested_tree_focus = key
          end,
        }
      end,
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
  })

  action.goto_next_entry(ctx)
  t.assert_eq(beta, current, "fallback next")
  action.goto_prev_entry(ctx)
  t.assert_eq(alpha, current, "fallback previous")
  t.assert_eq(2, #opened, "fallback previews")
end)

t:test("goto file preserves a literal POSIX backslash", function()
  local repo = vim.fn.tempname() ---@type string
  local relative = "back\\slash.lua"
  local filepath = repo .. "/" .. relative
  vim.fn.mkdir(repo, "p")
  vim.fn.writefile({ "content" }, filepath)
  workspace = repo

  local action = load_action(nil, {})
  local target_tabnr = vim.api.nvim_get_current_tabpage() ---@type integer
  vim.cmd.tabnew()
  local diff_tabnr = vim.api.nvim_get_current_tabpage() ---@type integer
  local changes_bufnr = vim.api.nvim_create_buf(false, true) ---@type integer
  local ctx = require("__test__.support.diffview").workspace_context({
    layout = { changes_bufnr = changes_bufnr },
    state = {
      get_tree = function()
        return {
          focus_key = function(_, key)
            requested_tree_focus = key
          end,
        }
      end,
      get_current_entry = function()
        return { filepath = relative, stage_type = "unstaged", status = "M" }
      end,
    },
  })

  action.goto_file(ctx)

  t.assert_eq(target_tabnr, vim.api.nvim_get_current_tabpage(), "existing tab")
  t.assert_eq(vim.uv.fs_realpath(filepath), vim.api.nvim_buf_get_name(0), "literal filepath")

  vim.api.nvim_set_current_tabpage(diff_tabnr)
  vim.cmd.tabclose()
  vim.cmd.enew()
  vim.api.nvim_buf_delete(changes_bufnr, { force = true })
  vim.fn.delete(repo, "rf")
  workspace = "/repo"
end)

t:test("toggle_sidebar restores Changes and History, then focuses the current entry", function()
  local action = load_action({}, {})
  local view = package.loaded["era.m.diffview.view.workspace.view"]
  local calls = {} ---@type string[]
  local visible = false
  t:patch_table(view, "toggle_sidebar", function(lyt)
    calls[#calls + 1] = "toggle"
    visible = not visible
    return lyt, visible
  end)
  t:patch_table(view, "render_changes", function()
    calls[#calls + 1] = "render_changes"
  end)
  t:patch_table(view, "focus_changes", function(_, stage_type)
    calls[#calls + 1] = "focus_" .. tostring(stage_type)
  end)
  local history = {}
  t:patch_table(package.loaded, "era.m.diffview.view.commits.view", {
    render_commits = function(actual)
      t.assert_true(actual == history, "the session's History")
      calls[#calls + 1] = "render_history"
    end,
  })
  local ctx = require("__test__.support.diffview").workspace_context({
    layout = {},
    history = history,
    state = {
      get_current_entry = function()
        return { stage_type = "unstaged" }
      end,
    },
    setup_changes = function()
      calls[#calls + 1] = "setup_changes"
    end,
    setup_history = function()
      calls[#calls + 1] = "setup_history"
    end,
  })

  action.toggle_sidebar(ctx)
  t.assert_eq(
    "toggle,setup_changes,render_changes,setup_history,render_history,focus_unstaged",
    table.concat(calls, ","),
    "showing restores the sidebar"
  )
  calls = {}
  action.toggle_sidebar(ctx)
  t.assert_eq("toggle", table.concat(calls, ","), "hiding renders nothing")
end)

t:run()
