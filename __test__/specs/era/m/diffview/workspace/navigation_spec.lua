require("ark.bootstrap").setup()
local t = require("__test__.support.harness").new()
local diffview = require("__test__.support.diffview")
local git = require("__test__.support.git")
local action = require("era.m.diffview.view.workspace.action")
local commits_view = require("era.m.diffview.view.commits.view")
local pane_changes = require("era.m.diffview.pane.changes")
local tree = require("era.m.diffview.pane.tree")
local workspace_view = require("era.m.diffview.view.workspace.view")

---@class era.m.diffview.test.INavigationRepository
---@field edited                         ?string[] Committed, then edited.
---@field staged                         ?string[] Edited files that are also staged.
---@field untracked                      ?string[]

---Opens the workspace on a repository shaped by `opts`.
---@param opts                          era.m.diffview.test.INavigationRepository
---@return era.m.diffview.WorkspaceSession
---@return string root
local function open(opts)
  local files = {} ---@type table<string, string[]>
  for _, path in ipairs(opts.edited or {}) do
    files[path] = { "base" }
  end
  local root = diffview.committed(t, files)
  for _, path in ipairs(opts.edited or {}) do
    diffview.write(root, path, { "changed" })
  end
  if opts.staged then
    git.run(root, vim.list_extend({ "add", "--" }, opts.staged))
  end
  for _, path in ipairs(opts.untracked or {}) do
    diffview.write(root, path, { "new" })
  end
  return diffview.open_workspace(t), root
end

---Records the previews opened for the rest of the case instead of opening them.
---@return era.m.diffview.IFileEntry[]
local function record_previews()
  local opened = {} ---@type era.m.diffview.IFileEntry[]
  t:patch_table(workspace_view, "open_entry", function(_, entry)
    opened[#opened + 1] = entry
  end)
  return opened
end

---Records the last row identity the Changes trees are asked to focus.
---@param session                       era.m.diffview.WorkspaceSession
---@return { key: string|nil }
local function record_tree_focus(session)
  local focus = { key = nil }
  for _, stage_type in ipairs({ "staged", "unstaged" }) do
    local owner = session.state:get_tree(stage_type)
    local focus_key = owner.focus_key
    t:patch_table(owner, "focus_key", function(self, key, ...)
      focus.key = key
      return focus_key(self, key, ...)
    end)
  end
  return focus
end

---@param session                       era.m.diffview.WorkspaceSession
---@param path                          string
---@param stage_type                    "staged"|"unstaged"
---@return nil
local function select(session, path, stage_type)
  session.state:set_current_entry(assert(session.state:find_entry(path, stage_type)))
end

---@param session                       era.m.diffview.WorkspaceSession
---@return string|nil
local function current(session)
  local entry = session.state:get_current_entry()
  return entry and (entry.stage_type .. ":" .. entry.filepath)
end

t:test("changes panel order groups stages and follows filetree traversal", function()
  local unstaged = { filepath = "a.lua", stage_type = "unstaged", status = "M" }
  local staged_root = { filepath = "z.lua", stage_type = "staged", status = "M" }
  local staged_nested = { filepath = "dir/a.lua", stage_type = "staged", status = "M" }

  local ordered = pane_changes.get_entries_in_render_order({ unstaged, staged_root, staged_nested })

  t.assert_eq(staged_nested, ordered[1], "nested staged entry")
  t.assert_eq(staged_root, ordered[2], "root staged entry")
  t.assert_eq(unstaged, ordered[3], "unstaged entry")
end)

t:test("hiding untracked files selects the first remaining rendered entry", function()
  local flag_untracked = dot.context.diffview.flag_untracked
  local initial = flag_untracked:snapshot() ---@type boolean
  t:defer(function()
    flag_untracked:next(initial)
  end)
  flag_untracked:next(true)
  local session = open({ edited = { "dir/hidden.lua", "tracked.lua" }, untracked = { "new.lua" } })
  diffview.collapse(t, session, "unstaged", "dir", "dir/hidden.lua")
  select(session, "new.lua", "unstaged")
  local opened = record_previews()
  local dirty = 0
  t:patch_table(dot.state.status.dirtier_tabline, "mark_dirty", function()
    dirty = dirty + 1
  end)

  action.toggle_untracked(session)

  t.assert_false(flag_untracked:snapshot(), "untracked visibility")
  t.assert_eq("unstaged:tracked.lua", current(session), "remaining selection")
  t.assert_eq("tracked.lua", opened[1] and opened[1].filepath, "remaining preview")
  t.assert_eq(1, dirty, "tabline dirtied")
end)

t:test("cross-pane navigation follows visible changes order and wraps", function()
  local session = open({ edited = { "a.lua", "b.lua", "collapsed/hidden.lua" }, staged = { "a.lua" } })
  diffview.collapse(t, session, "unstaged", "collapsed", "collapsed/hidden.lua")
  select(session, "a.lua", "staged")
  diffview.cursor_on(session, "staged", "a.lua")
  local opened = record_previews()
  local focus = record_tree_focus(session)
  local staged_winnr = session.layout.changes.staged.winnr
  local unstaged_winnr = session.layout.changes.unstaged.winnr

  action.goto_next_entry(session)
  t.assert_eq("unstaged:b.lua", current(session), "next visible entry")
  t.assert_eq(unstaged_winnr, vim.api.nvim_get_current_win(), "next pane")
  t.assert_eq(tree.key(nil, "b.lua", false), focus.key, "next cursor identity")

  action.goto_next_entry(session)
  t.assert_eq("staged:a.lua", current(session), "next wraps")
  t.assert_eq(staged_winnr, vim.api.nvim_get_current_win(), "wrapped pane")
  t.assert_eq(tree.key(nil, "a.lua", false), focus.key, "wrapped cursor identity")

  action.goto_prev_entry(session)
  t.assert_eq("unstaged:b.lua", current(session), "previous wraps")
  t.assert_eq(3, #opened, "preview count")
  t.assert_eq("b.lua", opened[3].filepath, "previous preview")
end)

t:test("navigation skips a hidden current entry without losing direction", function()
  local session = open({ edited = { "a/before.lua", "b/hidden.lua", "c/after.lua" } })
  diffview.collapse(t, session, "unstaged", "b", "b/hidden.lua")
  local opened = record_previews()

  select(session, "b/hidden.lua", "unstaged")
  action.goto_next_entry(session)
  t.assert_eq("unstaged:c/after.lua", current(session), "next visible entry after hidden current")

  select(session, "b/hidden.lua", "unstaged")
  action.goto_prev_entry(session)
  t.assert_eq("unstaged:a/before.lua", current(session), "previous visible entry before hidden current")
  t.assert_eq(2, #opened, "preview count")
end)

t:test("navigation does not enter entries hidden by the rendered panel", function()
  local session = open({ edited = { "collapsed/hidden.lua" } })
  diffview.collapse(t, session, "unstaged", "collapsed", "collapsed/hidden.lua")
  select(session, "collapsed/hidden.lua", "unstaged")
  local opened = record_previews()

  action.goto_next_entry(session)
  t.assert_eq("unstaged:collapsed/hidden.lua", current(session), "selection unchanged")
  t.assert_eq(0, #opened, "no hidden preview")
end)

t:test("reveal expands hidden entry ancestors, focuses the entry, then hides Changes", function()
  local session = open({ edited = { "middle/hidden.lua" } })
  diffview.collapse(t, session, "unstaged", "middle", "middle/hidden.lua")
  select(session, "middle/hidden.lua", "unstaged")
  local focus = record_tree_focus(session)
  vim.api.nvim_set_current_win(session.layout.sbs_left_winnr)

  action.reveal(session)
  t.assert_false(session.state:is_collapsed("unstaged", "middle"), "ancestor expanded")
  t.assert_eq(session.layout.changes.unstaged.winnr, vim.api.nvim_get_current_win(), "Changes focused")
  t.assert_eq(tree.key(nil, "middle/hidden.lua", false), focus.key, "entry cursor identity")

  action.reveal(session)
  t.assert_nil(session.layout.changes.staged.winnr, "Staged hidden")
  t.assert_nil(session.layout.changes.unstaged.winnr, "Unstaged hidden")
end)

t:test("navigation falls back to state order without a changes panel", function()
  local session = open({ edited = { "a.lua", "b.lua" }, staged = { "a.lua" } })
  select(session, "a.lua", "staged")
  workspace_view.hide_changes(session.layout)
  local opened = record_previews()

  action.goto_next_entry(session)
  t.assert_eq("unstaged:b.lua", current(session), "fallback next")
  action.goto_prev_entry(session)
  t.assert_eq("staged:a.lua", current(session), "fallback previous")
  t.assert_eq(2, #opened, "fallback previews")
end)

t:test("goto file preserves a literal POSIX backslash", function()
  local relative = "back\\slash.lua"
  local target_tabnr = vim.api.nvim_get_current_tabpage() ---@type integer
  local session, root = open({ edited = { relative } })
  select(session, relative, "unstaged")
  local filepath = root .. "/" .. relative

  action.goto_file(session)
  local bufnr = vim.api.nvim_get_current_buf() ---@type integer
  t:defer(function()
    vim.api.nvim_buf_delete(bufnr, { force = true })
  end)

  t.assert_eq(target_tabnr, vim.api.nvim_get_current_tabpage(), "existing tab")
  t.assert_eq(vim.uv.fs_realpath(filepath), vim.api.nvim_buf_get_name(bufnr), "literal filepath")
end)

t:test("toggle_sidebar restores Changes and History, then focuses the current entry", function()
  local session = open({ edited = { "a.lua" } })
  local calls = {} ---@type string[]
  local function record(target, name, label)
    local original = target[name]
    t:patch_table(target, name, function(...)
      calls[#calls + 1] = type(label) == "function" and label(...) or label
      return original(...)
    end)
  end
  record(workspace_view, "toggle_sidebar", "toggle")
  record(session, "setup_changes", "setup_changes")
  record(workspace_view, "render_changes", "render_changes")
  record(session, "setup_history", "setup_history")
  record(commits_view, "render_commits", function(ctx)
    t.assert_true(ctx == session.history, "the session's History")
    return "render_history"
  end)
  record(workspace_view, "focus_changes", function(_, stage_type)
    return "focus_" .. tostring(stage_type)
  end)

  action.toggle_sidebar(session)
  t.assert_eq("toggle", table.concat(calls, ","), "hiding renders nothing")
  calls = {}
  action.toggle_sidebar(session)
  t.assert_eq(
    "toggle,setup_changes,render_changes,setup_history,render_history,focus_unstaged",
    table.concat(calls, ","),
    "showing restores the sidebar"
  )
end)

t:run()
