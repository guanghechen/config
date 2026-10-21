require("ark.bootstrap").setup()
local t = require("__test__.support.harness").new()
local diffview = require("__test__.support.diffview")
local action = require("era.m.diffview.view.workspace.action")
local workspace_view = require("era.m.diffview.view.workspace.view")

---Opens the workspace on a repository of a.lua, b.lua and c.lua whose `changed` files have unstaged edits.
---@param changed                       string[]
---@return era.m.diffview.WorkspaceSession
local function open(changed)
  local root = diffview.committed(t, { ["a.lua"] = { "a" }, ["b.lua"] = { "b" }, ["c.lua"] = { "c" } })
  for _, path in ipairs(changed) do
    diffview.write(root, path, { "changed " .. path })
  end
  return diffview.open_workspace(t)
end

---A fresh copy of the session's entry, as a new snapshot carries it.
---@param session                       era.m.diffview.WorkspaceSession
---@param path                          string
---@param stage_type                    ?"staged"|"unstaged"
---@return era.m.diffview.IFileEntry
local function entry(session, path, stage_type)
  local found = session.state:find_entry(path, "unstaged")
  local copy = vim.deepcopy(found or { filepath = path, status = "M" })
  copy.stage_type = stage_type or "unstaged"
  return copy
end

---@class era.m.diffview.test.IApplied
---@field opened                         era.m.diffview.IFileEntry[]
---@field open_opts                      era.m.diffview.view.workspace.IOpenEntryOpts[]
---@field cleared                        integer
---@field renders                        integer
---@field height_syncs                   integer
---@field sets                           integer
---@field commits                        integer

---Records what applying snapshots does to the session for the rest of the case. Previews are recorded rather than
---opened; `failures` makes the next renders or preview cleanups fail.
---@param session                       era.m.diffview.WorkspaceSession
---@param failures                      ?{ render: integer|nil, clear: integer|nil }
---@return era.m.diffview.test.IApplied
local function observe(session, failures)
  failures = failures or {}
  local seen = { opened = {}, open_opts = {}, cleared = 0, renders = 0, height_syncs = 0, sets = 0, commits = 0 }
  t:patch_table(workspace_view, "open_entry", function(_, opened, _, opts)
    seen.opened[#seen.opened + 1] = opened
    seen.open_opts[#seen.open_opts + 1] = opts
  end)
  local clear_sbs = workspace_view.clear_sbs
  t:patch_table(workspace_view, "clear_sbs", function(...)
    if (failures.clear or 0) > 0 then
      failures.clear = failures.clear - 1
      error("injected clear failure")
    end
    seen.cleared = seen.cleared + 1
    return clear_sbs(...)
  end)
  local render_changes = workspace_view.render_changes
  t:patch_table(workspace_view, "render_changes", function(...)
    seen.renders = seen.renders + 1
    if (failures.render or 0) > 0 then
      failures.render = failures.render - 1
      error("injected render failure")
    end
    return render_changes(...)
  end)
  local sync_changes_heights = workspace_view.sync_changes_heights
  t:patch_table(workspace_view, "sync_changes_heights", function(...)
    seen.height_syncs = seen.height_syncs + 1
    return sync_changes_heights(...)
  end)
  local state = session.state
  local set_entries, commit_entries_snapshot = state.set_entries, state.commit_entries_snapshot
  t:patch_table(state, "set_entries", function(self, entries)
    seen.sets = seen.sets + 1
    return set_entries(self, entries)
  end)
  t:patch_table(state, "commit_entries_snapshot", function(self)
    seen.commits = seen.commits + 1
    return commit_entries_snapshot(self)
  end)
  return seen
end

---Applies `entries` to the session and waits.
---@param session                       era.m.diffview.WorkspaceSession
---@param entries                       era.m.diffview.IFileEntry[]
---@param token                         ?stl.c.CancellationToken
---@return boolean ok                   Whether applying completed without an error.
local function apply(session, entries, token)
  local settled, ok = false, false
  stl.async
    .run_future(function()
      action.apply_entries(session, entries, token)
    end)
    :finally(function(resolved)
      settled, ok = true, resolved
    end)
  t.wait_until(function()
    return settled
  end, 5000, "applied entries")
  return ok
end

t:test("the first snapshot is committed and rendered even when it is empty", function()
  local session = open({})
  session.state:set_entries({})
  local seen = observe(session)

  t.assert_true(apply(session, {}), "applied")
  t.assert_nil(session.state:get_current_entry(), "selection remains empty")
  t.assert_eq(0, #seen.opened, "no preview opened")
  t.assert_eq(1, seen.sets, "initial snapshot committed")
  t.assert_eq(1, seen.renders, "empty panes rendered")
  t.assert_eq(1, seen.commits, "initial snapshot marked applied")
  t.assert_eq(0, seen.cleared, "already empty preview not rewritten")
end)

t:test("an unchanged snapshot keeps the panes but refreshes the selected preview", function()
  local session = open({ "a.lua" })
  local current = session.state:get_current_entry()
  local seen = observe(session)

  t.assert_true(apply(session, { entry(session, "a.lua") }), "applied")
  t.assert_true(session.state:get_current_entry() == current, "existing canonical selection retained")
  t.assert_true(seen.opened[1] == current, "selected preview refreshed from existing snapshot")
  t.assert_true(seen.open_opts[1].preserve_view, "same preview preserves view")
  t.assert_eq(0, seen.sets, "state snapshot not replaced")
  t.assert_eq(0, seen.renders, "Changes panes not rendered")
  t.assert_eq(0, seen.commits, "already applied snapshot not recommitted")
  t.assert_eq(1, seen.height_syncs, "cheap pane height invariant synchronized")
  t.assert_eq(0, seen.cleared, "preview retained")
end)

t:test("a failed render keeps the snapshot pending so an identical retry completes", function()
  local session = open({ "a.lua" })
  local seen = observe(session, { render = 1 })
  local refreshed = { entry(session, "a.lua"), entry(session, "b.lua") }

  t.assert_false(apply(session, refreshed), "injected render failure propagated")
  t.assert_eq(0, seen.commits, "failed snapshot remains pending")

  t.assert_true(apply(session, refreshed), "retry applied")
  t.assert_true(session.state:get_current_entry() == refreshed[1], "retry commits canonical selection")
  t.assert_true(seen.opened[1] == refreshed[1], "retry opens refreshed preview")
  t.assert_eq(2, seen.sets, "identical retry still takes slow path")
  t.assert_eq(2, seen.renders, "failed render retried")
  t.assert_eq(1, seen.commits, "retry marks snapshot applied")
end)

t:test("a failed preview cleanup preserves the selection until an identical retry completes", function()
  local session = open({ "a.lua" })
  local removed = session.state:get_current_entry()
  local seen = observe(session, { clear = 1 })

  t.assert_false(apply(session, {}), "injected cleanup failure propagated")
  t.assert_true(session.state:get_current_entry() == removed, "failed cleanup keeps prior selection for retry")
  t.assert_eq(0, seen.commits, "failed snapshot remains pending")

  t.assert_true(apply(session, {}), "retry applied")
  t.assert_nil(session.state:get_current_entry(), "retry clears selection")
  t.assert_eq(1, seen.cleared, "retry completes preview cleanup")
  t.assert_eq(2, seen.sets, "identical retry still takes slow path")
  t.assert_eq(2, seen.renders, "retry restores panel application")
  t.assert_eq(1, seen.commits, "retry marks snapshot applied")
end)

t:test("a changed snapshot rebinds the selection to its canonical entry", function()
  local session = open({ "a.lua" })
  local seen = observe(session)
  local refreshed = { entry(session, "a.lua"), entry(session, "c.lua") }

  t.assert_true(apply(session, refreshed), "applied")
  t.assert_true(session.state:get_current_entry() == refreshed[1], "canonical selection")
  t.assert_true(seen.opened[1] == refreshed[1], "canonical preview")
  t.assert_true(seen.open_opts[1].preserve_view, "same entry preserves view")
  t.assert_eq(0, seen.cleared, "preview retained")
end)

t:test("the selection follows a file across a stage transition", function()
  local session = open({ "a.lua" })
  local seen = observe(session)
  local staged = entry(session, "a.lua", "staged")

  t.assert_true(apply(session, { staged }), "applied")
  t.assert_true(session.state:get_current_entry() == staged, "staged counterpart")
  t.assert_true(seen.opened[1] == staged, "staged preview")
  t.assert_false(seen.open_opts[1].preserve_view, "stage transition replaces view")
end)

t:test("the next visible entry is selected when the current one disappears", function()
  local session = open({ "a.lua", "b.lua", "c.lua" })
  session.state:set_current_entry(assert(session.state:find_entry("b.lua", "unstaged")))
  local seen = observe(session)
  local refreshed = { entry(session, "a.lua"), entry(session, "c.lua") }

  t.assert_true(apply(session, refreshed), "applied")
  t.assert_true(session.state:get_current_entry() == refreshed[2], "next selection")
  t.assert_true(seen.opened[1] == refreshed[2], "next preview")
end)

t:test("the previous visible entry is selected when no later one remains", function()
  local session = open({ "a.lua", "b.lua" })
  session.state:set_current_entry(assert(session.state:find_entry("b.lua", "unstaged")))
  local seen = observe(session)
  local refreshed = { entry(session, "a.lua") }

  t.assert_true(apply(session, refreshed), "applied")
  t.assert_true(session.state:get_current_entry() == refreshed[1], "previous selection")
  t.assert_true(seen.opened[1] == refreshed[1], "previous preview")
end)

t:test("the selection and preview clear when no entries remain", function()
  local session = open({ "a.lua" })
  local seen = observe(session)

  t.assert_true(apply(session, {}), "applied")
  t.assert_nil(session.state:get_current_entry(), "cleared selection")
  t.assert_eq(0, #seen.opened, "no preview")
  t.assert_eq(1, seen.cleared, "preview cleared")
end)

t:test("a cancelled refresh leaves the view alone", function()
  local session = open({ "a.lua" })
  local current = session.state:get_current_entry()
  local seen = observe(session)
  local token = stl.c.CancellationToken.new()
  token:cancel()

  t.assert_true(apply(session, { entry(session, "a.lua", "staged") }, token), "applied")
  t.assert_true(session.state:get_current_entry() == current, "selection unchanged")
  t.assert_eq(0, #seen.opened, "preview unchanged")
  t.assert_eq(0, seen.cleared, "preview not cleared")
  t.assert_eq(0, seen.sets, "snapshot unchanged")
end)

t:run()
