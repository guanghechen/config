require("ark.bootstrap").setup()
local t = require("__test__.support.harness").new()
local diffview = require("__test__.support.diffview")
local git = require("__test__.support.git")
local Session = require("era.m.diffview.session")
local commits_view = require("era.m.diffview.view.commits.view")
local pane_sbs = require("era.m.diffview.pane.sbs")
local workspace_view = require("era.m.diffview.view.workspace.view")

---Runs the callbacks Observable notifications schedule.
---@return nil
local function flush()
  local flushed = false
  vim.schedule(function()
    flushed = true
  end)
  t.wait_until(function()
    return flushed
  end, 1000, "scheduled callbacks")
end

---Types `keys` into a new window in the current tab that shows `bufnr`.
---@param bufnr                         integer
---@param keys                          string
---@return nil
local function type_into(bufnr, keys)
  vim.cmd("split")
  local winnr = vim.api.nvim_get_current_win()
  vim.api.nvim_win_set_buf(winnr, bufnr)
  vim.api.nvim_feedkeys(vim.api.nvim_replace_termcodes(keys, true, false, true), "xt", false)
  vim.api.nvim_win_close(winnr, true)
end

t:test("opening selects the first file in panel order and seeds both states with the default folds", function()
  diffview.repository(t)
  local session = diffview.open_workspace(t)
  t.wait_until(function()
    return session.state:get_current_entry() ~= nil
  end, 10000, "first entry")

  -- a.txt sorts first, but Staged precedes Unstaged.
  t.assert_eq("c.txt", session.state:get_current_entry().filepath)
  t.assert_eq(session.layout.changes.staged.winnr, vim.api.nvim_get_current_win(), "the cursor starts in Staged")
  local fold_unchanged = dot.context.diffview.flag_fold_unchanges:snapshot()
  t.assert_eq(fold_unchanged, session.state:get_fold_unchanged(), "workspace folds")
  t.assert_eq(fold_unchanged, session.history.state:get_fold_unchanged(), "History folds")
end)

t:test("opening again returns to the workspace, and a log without a path opens its own tab", function()
  diffview.repository(t)
  local workspace = diffview.open_workspace(t)
  vim.cmd.tabfirst()
  t.assert_true(Session.open_workspace() == workspace, "the open workspace")
  t.assert_eq(workspace.tabnr, vim.api.nvim_get_current_tabpage(), "its tab")

  local log = diffview.open_log(t)
  t.assert_true(log.tabnr ~= workspace.tabnr, "the log has its own tab")
  vim.cmd.tabfirst()
  t.assert_true(Session.open_log() == log, "the same unfiltered log")
  t.assert_true(Session.workspace(workspace.tabnr) == workspace and Session.commits(log.tabnr) == log, "lookups")
end)

t:test("a workspace closes with its tab and releases History even when it is hidden", function()
  diffview.repository(t)
  local session = diffview.open_workspace(t)
  local history_bufnr = assert(session.layout.history.commits_bufnr)
  session:toggle_commits()
  t.assert_nil(session.layout.history.commits_winnr, "History hidden")

  vim.cmd.tabclose()
  t.assert_true(session:is_closed(), "session closed")
  t.assert_true(session.state:is_disposed(), "workspace state disposed")
  t.assert_true(session.history.state:is_disposed(), "History state disposed")
  t.assert_false(vim.api.nvim_buf_is_valid(history_bufnr), "History buffer released")
  t.assert_nil(Session.workspace(session.tabnr), "no session for the closed tab")
end)

t:test("a log closes with its tab", function()
  diffview.repository(t)
  local session = diffview.open_log(t, { path = "a.txt" })
  vim.cmd.tabclose()
  t.assert_true(session:is_closed(), "session closed")
  t.assert_true(session.state:is_disposed(), "state disposed")
  t.assert_nil(Session.commits(session.tabnr), "no session for the closed tab")
end)

t:test("a session whose tab closed unnoticed closes when it is looked up", function()
  diffview.repository(t)
  local log = diffview.open_log(t, { path = "a.txt" })
  vim.cmd("noautocmd tabclose")
  t.assert_false(log:is_closed(), "the tab closed without TabClosed")

  local again = diffview.open_log(t, { path = "a.txt" })
  t.assert_true(log:is_closed(), "the stale session closed")
  t.assert_true(again ~= log and vim.api.nvim_tabpage_is_valid(again.tabnr), "a new log")
end)

t:test("moving left from the left preview returns to Changes", function()
  diffview.repository(t)
  local session = diffview.open_workspace(t)
  vim.api.nvim_set_current_win(assert(session.layout.sbs_left_winnr))
  t.assert_false(session:navigate_window("l"), "other directions stay native")
  t.assert_true(session:navigate_window("h"), "handled")
  local current = vim.api.nvim_get_current_win()
  t.assert_true(
    current == session.layout.changes.staged.winnr or current == session.layout.changes.unstaged.winnr,
    "a Changes pane"
  )
  t.assert_false(session:navigate_window("h"), "from Changes it stays native")
end)

t:test("Git index events refresh Changes only when stale, and broader events always", function()
  diffview.repository(t)
  local session = diffview.open_workspace(t)
  local forced, checks = 0, 0
  t:patch_table(session.state, "request_refresh", function()
    forced = forced + 1
  end)
  t:patch_table(session.state, "request_refresh_if_stale", function()
    checks = checks + 1
  end)

  era.m.git.state.o_refreshed:next({ change_scope = "index", generation = 1000 })
  flush()
  t.assert_eq(1, checks, "an index event checks the snapshot")
  t.assert_eq(0, forced, "an index event does not force")

  era.m.git.state.o_refreshed:next({ change_scope = "unknown", generation = 1001 })
  flush()
  t.assert_eq(1, checks, "a broader event skips the identity check")
  t.assert_eq(1, forced, "a broader event refreshes")
end)

t:test("closing stops Git events before the refresh owner goes", function()
  diffview.repository(t)
  local session = diffview.open_workspace(t)
  local requests = 0
  for _, name in ipairs({ "request_refresh", "request_refresh_if_stale" }) do
    t:patch_table(session.state, name, function()
      requests = requests + 1
    end)
  end

  session:close()
  era.m.git.state.o_refreshed:next({ change_scope = "unknown", generation = 2000 })
  flush()
  t.assert_eq(0, requests)
end)

t:test("History and Changes previews hand the shared panes to the latest one", function()
  diffview.repository(t)
  local session = diffview.open_workspace(t)
  local changes, history = {}, {} ---@type table[], table[]
  t:patch_table(pane_sbs, "open_diff_entry", function(opts)
    changes[#changes + 1] = opts
  end)
  t:patch_table(pane_sbs, "open_commit_entry", function(opts)
    history[#history + 1] = opts
  end)
  local commit = session.history.state:get_commits()[1]

  workspace_view.open_entry(session, { filepath = "a.txt", stage_type = "unstaged", status = "M" })
  commits_view.open_entry(session.history, commit, { filepath = "b.txt", status = "A" })
  t.assert_false(changes[1].is_current(), "History supersedes Changes")
  t.assert_true(history[1].is_current(), "History owns the shared preview")
  t.assert_eq("history", session.layout.preview_source)

  workspace_view.open_entry(session, { filepath = "a.txt", stage_type = "unstaged", status = "M" })
  t.assert_false(history[1].is_current(), "Changes supersede History")
  t.assert_true(changes[2].is_current(), "Changes own the shared preview")
  t.assert_eq("changes", session.layout.preview_source)

  session:close()
  t.assert_false(changes[2].is_current(), "a closed session owns no preview")
end)

t:test("previews take the filetype of their file without turning on filetype detection", function()
  local root = diffview.repository(t)
  vim.fn.writefile({ "return 1" }, root .. "/x.lua")
  git.run(root, { "add", "x.lua" })
  local session = diffview.open_workspace(t)
  local function detection()
    return vim.fn.execute("filetype"):match("detection:(%u+)")
  end
  -- A spec process starts without detection; no preview in this file may have turned it on.
  t.assert_eq("OFF", detection(), "filetype detection before")

  local entry = assert(session.state:find_entry("x.lua", "staged"))
  stl.async.run(function()
    workspace_view.open_entry(session, entry)
  end)
  t.wait_until(function()
    return vim.bo[vim.api.nvim_win_get_buf(session.layout.sbs_right_winnr)].filetype == "lua"
  end, 5000, "the x.lua preview is Lua")
  t.assert_eq("OFF", detection(), "filetype detection after")
end)

t:test("a log keeps only its latest preview", function()
  diffview.repository(t)
  local session = diffview.open_log(t, { layout = 1 })
  local requests = {} ---@type table[]
  t:patch_table(pane_sbs, "open_commit_entry", function(opts)
    requests[#requests + 1] = opts
  end)
  local commit = session.state:get_commits()[1]

  commits_view.open_entry(session, commit, { filepath = "a.txt", status = "A" })
  commits_view.open_entry(session, commit, { filepath = "b.txt", status = "A" })
  t.assert_false(requests[1].is_current(), "the earlier preview")
  t.assert_true(requests[2].is_current(), "the latest preview")

  session:close()
  t.assert_false(requests[2].is_current(), "a closed session owns no preview")
end)

t:test("shared side-by-side mappings run the keymap of the current tab's session", function()
  diffview.repository(t)
  local workspace = diffview.open_workspace(t)
  local log = diffview.open_log(t, { layout = 1 })
  local calls = {} ---@type string[]
  t:patch_table(require("era.m.diffview.view.workspace.action"), "goto_next_entry", function()
    calls[#calls + 1] = "workspace"
  end)
  t:patch_table(require("era.m.diffview.view.commits.action"), "goto_next_commit", function()
    calls[#calls + 1] = "log"
  end)
  -- A preview buffer is shared by the tabs that show it, so it carries the mappings of both.
  local bufnr = vim.api.nvim_create_buf(false, true)
  t:defer(function()
    vim.api.nvim_buf_delete(bufnr, { force = true })
  end)
  workspace:setup_sbs(bufnr)
  log:setup_sbs(bufnr)

  vim.api.nvim_set_current_tabpage(workspace.tabnr)
  type_into(bufnr, "<C-j>")
  vim.api.nvim_set_current_tabpage(log.tabnr)
  type_into(bufnr, "<C-j>")
  t.assert_eq("workspace,log", table.concat(calls, ","))
end)

t:test("shared side-by-side mappings keep counts for handled and fallback keys", function()
  diffview.repository(t)
  local session = diffview.open_workspace(t)
  local handled_count = nil ---@type integer|nil
  t:patch_table(require("era.m.diffview.view.workspace.keymap"), "gen_sbs", function(ctx)
    if ctx.layout.preview_source == "history" then
      return {}
    end
    -- stylua: ignore
    return { { modes = { "n" }, key = "P", desc = "count probe", callback = function() handled_count = vim.v.count end } }
  end)
  local bufnr = vim.api.nvim_create_buf(false, true)
  t:defer(function()
    vim.api.nvim_buf_delete(bufnr, { force = true })
  end)
  vim.api.nvim_buf_set_lines(bufnr, 0, -1, false, { "a" })
  local register, register_type = vim.fn.getreg('"'), vim.fn.getregtype('"')
  t:defer(function()
    vim.fn.setreg('"', register, register_type)
  end)
  vim.fn.setreg('"', "x", "v")
  session:setup_sbs(bufnr)

  type_into(bufnr, "4P")
  t.assert_eq(4, handled_count, "the handled mapping sees the count")
  t.assert_eq("a", vim.api.nvim_buf_get_lines(bufnr, 0, 1, false)[1], "a handled key does not fall back")

  session.layout.preview_source = "history"
  type_into(bufnr, "3P")
  t.assert_eq("xxxa", vim.api.nvim_buf_get_lines(bufnr, 0, 1, false)[1], "the fallback keeps the native count")
end)

t:test("resizing Changes renders them again and remembers the width until the session closes", function()
  diffview.repository(t)
  local session = diffview.open_workspace(t)
  local widths, renders = {}, 0 ---@type integer[], integer
  t:patch_table(dot.context.diffview.panel_width, "next", function(_, width)
    widths[#widths + 1] = width
  end)
  local render = workspace_view.render_changes
  t:patch_table(workspace_view, "render_changes", function(...)
    renders = renders + 1
    return render(...)
  end)

  local staged = assert(session.layout.changes.staged.winnr)
  vim.api.nvim_win_set_width(staged, vim.api.nvim_win_get_width(staged) - 4)
  vim.api.nvim_exec_autocmds("WinResized", {})
  t.assert_eq(1, renders, "render")
  t.assert_same({ vim.api.nvim_win_get_width(staged) }, widths, "remembered width")

  session:close()
  vim.api.nvim_exec_autocmds("WinResized", {})
  t.assert_eq(1, renders, "a closed session no longer watches")
end)

-- Closing the only tab leaves the tab open, so this case runs last.
t:test("a session closed on the last tab is no longer found", function()
  diffview.repository(t)
  local session = diffview.open_workspace(t)
  vim.cmd("tabonly")
  session:close()
  t.assert_true(vim.api.nvim_tabpage_is_valid(session.tabnr), "the last tab stays")
  t.assert_nil(Session.current(), "no session")
end)

t:run()
