require("ark.bootstrap").setup()
local t = require("__test__.support.harness").new()
local diffview = require("__test__.support.diffview")
local treeview = require("__test__.support.treeview")
local fs = require("__test__.support.fs")
local git = require("__test__.support.git")
local action = require("era.m.diffview.view.workspace.action")
local workspace_view = require("era.m.diffview.view.workspace.view")

---A workspace whose Changes panes both list files: a.lua to e.lua are edited and the first three staged.
---@return era.m.diffview.WorkspaceSession
local function open()
  local paths = { "a.lua", "b.lua", "c.lua", "d.lua", "e.lua" }
  local files = {} ---@type table<string, string[]>
  for _, path in ipairs(paths) do
    files[path] = { "base" }
  end
  local root = diffview.committed(t, files)
  for _, path in ipairs(paths) do
    fs.write(root .. "/" .. path, { "changed" })
  end
  git.run(root, { "add", "--", "a.lua", "b.lua", "c.lua" })
  return diffview.open_workspace(t)
end

---Puts the cursor of the Changes pane of `stage_type` on `path`, as a typed motion does, once the pane shows it.
---@param session                       era.m.diffview.WorkspaceSession
---@param stage_type                    "staged"|"unstaged"
---@param path                          string
---@return nil
local function move_to(session, stage_type, path)
  t.wait_until(function()
    return diffview.row(session, stage_type, path) ~= nil
  end, 5000, path .. " listed")
  diffview.cursor_on(session, stage_type, path)
  vim.cmd("doautocmd CursorMoved")
  treeview.await(session.state:get_tree(stage_type):ready())
end

---@param winnr                         integer
---@return integer
local function top(winnr)
  return vim.api.nvim_win_get_position(winnr)[1]
end

t:test("z; shows the focused pane alone, then brings the others back around it at their default heights", function()
  local session = open()
  local lyt = session.layout
  move_to(session, "unstaged", "d.lua")
  local winnr = assert(lyt.changes.unstaged.winnr)
  local height = vim.api.nvim_win_get_height(winnr)

  action.toggle_immersive(session)
  t.assert_same({ "unstaged" }, workspace_view.sidebar_panes(lyt))
  t.assert_eq(winnr, vim.api.nvim_get_current_win(), "the pane keeps its window and the focus")
  t.assert_true(vim.api.nvim_win_get_height(winnr) > height, "the pane takes the whole sidebar")

  action.toggle_immersive(session)
  t.assert_nil(lyt.immersive)
  t.assert_same({ "staged", "unstaged", "history" }, workspace_view.sidebar_panes(lyt))
  t.assert_eq(winnr, lyt.changes.unstaged.winnr, "the shown pane keeps its window")
  t.assert_eq(winnr, vim.api.nvim_get_current_win(), "and the focus")
  t.assert_eq(diffview.row(session, "unstaged", "d.lua"), vim.api.nvim_win_get_cursor(winnr)[1], "and its cursor")
  local staged_winnr, history_winnr = assert(lyt.changes.staged.winnr), assert(lyt.history.commits_winnr)
  t.assert_true(top(staged_winnr) < top(winnr) and top(winnr) < top(history_winnr), "column order")
  t.assert_eq(2, vim.api.nvim_win_get_height(history_winnr), "History shows one content row")
  local difference = vim.api.nvim_win_get_height(winnr) - vim.api.nvim_win_get_height(staged_winnr)
  t.assert_true(difference == 0 or difference == 1, "Changes split the rest evenly")
end)

t:test("leaving immersive mode keeps the cursor that the shrinking window and 'scrolloff' would move", function()
  local files = {} ---@type table<string, string[]>
  for index = 1, 30 do
    files[string.format("f%02d.lua", index)] = { "base" }
  end
  local root = diffview.committed(t, files)
  for path in pairs(files) do
    fs.write(root .. "/" .. path, { "changed" })
  end
  local session = diffview.open_workspace(t)
  local scrolloff = vim.o.scrolloff
  t:defer(function()
    vim.o.scrolloff = scrolloff
  end)
  vim.o.scrolloff = 4
  move_to(session, "unstaged", "f06.lua")
  local winnr = assert(session.layout.changes.unstaged.winnr)
  local cursor = vim.api.nvim_win_get_cursor(winnr)[1]

  action.toggle_immersive(session)
  action.toggle_immersive(session)
  t.assert_eq(cursor, vim.api.nvim_win_get_cursor(winnr)[1])
end)

t:test("]p and [p show the other panes in turn, each back on its own row", function()
  local session = open()
  local lyt = session.layout
  move_to(session, "staged", "b.lua")
  action.toggle_immersive(session)

  for _, expected in ipairs({ "unstaged", "history", "staged" }) do
    action.cycle_sidebar(session, 1)
    t.assert_same({ expected }, workspace_view.sidebar_panes(lyt), "]p to " .. expected)
    t.assert_eq(workspace_view.sidebar_pane_at(lyt, vim.api.nvim_get_current_win()), expected, "focus on " .. expected)
  end
  -- Staged returns in a new window, on the row its cursor left.
  local winnr = assert(lyt.changes.staged.winnr)
  t.wait_until(function()
    local row = diffview.row(session, "staged", "b.lua")
    return row ~= nil and vim.api.nvim_win_get_cursor(winnr)[1] == row
  end, 5000, "Staged back on b.lua")

  action.cycle_sidebar(session, -1)
  t.assert_same({ "history" }, workspace_view.sidebar_panes(lyt), "[p wraps backwards")
end)

t:test("outside immersive mode ]p moves the focus down the sidebar and wraps", function()
  local session = open()
  local lyt = session.layout
  move_to(session, "staged", "b.lua")
  for _, expected in ipairs({ "unstaged", "history", "staged" }) do
    action.cycle_sidebar(session, 1)
    t.assert_eq(workspace_view.sidebar_pane_at(lyt, vim.api.nvim_get_current_win()), expected)
  end
  t.assert_same({ "staged", "unstaged", "history" }, workspace_view.sidebar_panes(lyt), "no pane hides")
end)

t:test("the sidebar toggle hides and restores the immersive pane alone", function()
  local session = open()
  local lyt = session.layout
  vim.api.nvim_set_current_win(assert(lyt.history.commits_winnr))
  action.toggle_immersive(session)

  action.toggle_sidebar(session)
  t.assert_same({}, workspace_view.sidebar_panes(lyt), "hidden")
  action.toggle_sidebar(session)
  t.assert_same({ "history" }, workspace_view.sidebar_panes(lyt), "History alone again")
  t.assert_eq(lyt.history.commits_winnr, vim.api.nvim_get_current_win(), "focused")
end)

t:test("reveal shows the current entry's Changes pane in place of History", function()
  local session = open()
  local lyt = session.layout
  local current = assert(session.state:get_current_entry())
  vim.api.nvim_set_current_win(assert(lyt.history.commits_winnr))
  action.toggle_immersive(session)

  action.reveal(session)
  t.assert_same({ current.stage_type }, workspace_view.sidebar_panes(lyt))
  t.assert_eq(lyt.changes[current.stage_type].winnr, vim.api.nvim_get_current_win(), "focused")
end)

t:test("toggling History ends immersive mode first", function()
  local session = open()
  local lyt = session.layout
  vim.api.nvim_set_current_win(assert(lyt.changes.unstaged.winnr))
  action.toggle_immersive(session)

  action.toggle_history(session)
  t.assert_nil(lyt.immersive)
  t.assert_same({ "staged", "unstaged" }, workspace_view.sidebar_panes(lyt), "History was shown, so it hides")
end)

t:test("Changes revealed from History alone return as a pair, with History on its own row", function()
  local session = open()
  local lyt = session.layout
  vim.api.nvim_set_current_win(assert(lyt.changes.staged.winnr))
  action.reveal(session)
  t.assert_same({ "history" }, workspace_view.sidebar_panes(lyt), "History alone")
  vim.api.nvim_set_current_win(assert(lyt.history.commits_winnr))
  action.toggle_immersive(session)

  action.reveal(session)
  action.toggle_immersive(session)
  t.assert_same({ "staged", "unstaged", "history" }, workspace_view.sidebar_panes(lyt))
  t.assert_eq(2, vim.api.nvim_win_get_height(assert(lyt.history.commits_winnr)), "History shows one content row")
end)

t:test("staging the shown pane empty brings Staged in its place and the focus with it", function()
  local root = diffview.committed(t, { ["x.lua"] = { "x" }, ["y.lua"] = { "y" } })
  fs.write(root .. "/x.lua", { "changed" })
  fs.write(root .. "/y.lua", { "changed" })
  git.run(root, { "add", "--", "y.lua" })
  local session = diffview.open_workspace(t)
  local lyt = session.layout
  move_to(session, "unstaged", "x.lua")
  session.state:set_current_entry(assert(session.state:find_entry("x.lua", "unstaged")))
  action.toggle_immersive(session)
  local refreshes = diffview.count_refreshes(t, session.state)

  action.stage(session)
  diffview.await_refreshes(refreshes, 1)
  t.assert_same({ "staged" }, workspace_view.sidebar_panes(lyt), "Staged replaces the emptied Unstaged")
  t.assert_eq(lyt.changes.staged.winnr, vim.api.nvim_get_current_win(), "focused")
  t.wait_until(function()
    return diffview.row(session, "staged", "x.lua") ~= nil
  end, 5000, "Staged lists x.lua")
end)

t:test("]p and [p in a side-by-side window focus the pane of the preview, in place of the immersive pane", function()
  local session = open()
  local lyt = session.layout
  local current = assert(session.state:get_current_entry())
  local other = current.stage_type == "staged" and "unstaged" or "staged"
  workspace_view.begin_preview(lyt, "changes")
  vim.api.nvim_set_current_win(assert(lyt.changes[other].winnr))
  action.toggle_immersive(session)

  vim.api.nvim_set_current_win(assert(lyt.sbs_right_winnr))
  action.focus_preview_pane(session)
  t.assert_same({ current.stage_type }, workspace_view.sidebar_panes(lyt), "the preview's pane replaces " .. other)
  t.assert_eq(lyt.changes[current.stage_type].winnr, vim.api.nvim_get_current_win(), "focused")

  action.toggle_immersive(session)
  workspace_view.begin_preview(lyt, "history")
  vim.api.nvim_set_current_win(assert(lyt.sbs_right_winnr))
  action.focus_preview_pane(session)
  t.assert_eq(lyt.history.commits_winnr, vim.api.nvim_get_current_win(), "a History preview leads to History")
end)

t:test("sidebar panes keep their buffers against buffer switches, also the ones immersive mode recreates", function()
  local session = open()
  local lyt = session.layout
  local other = t:buffer()
  for _, name in ipairs({ "staged", "unstaged", "history" }) do
    local winnr = assert(name == "history" and lyt.history.commits_winnr or lyt.changes[name].winnr)
    local bufnr = vim.api.nvim_win_get_buf(winnr)
    vim.api.nvim_set_current_win(winnr)
    local ok, err = pcall(vim.cmd.buffer, other)
    t.assert_false(ok, name .. " refuses another buffer")
    t.assert_true(tostring(err):find("E1513", 1, true) ~= nil, name .. ": " .. tostring(err))
    t.assert_eq(bufnr, vim.api.nvim_win_get_buf(winnr), name .. " keeps its buffer")
  end

  vim.api.nvim_set_current_win(assert(lyt.changes.staged.winnr))
  action.toggle_immersive(session)
  action.cycle_sidebar(session, 1)
  t.assert_true(vim.wo[assert(lyt.changes.unstaged.winnr)].winfixbuf, "recreated Unstaged")
  action.toggle_immersive(session)
  t.assert_true(vim.wo[assert(lyt.changes.staged.winnr)].winfixbuf, "recreated Staged")
end)

---Maximizes `winnr` as the maximize command does from it; the case ends with no window maximized.
---@param winnr                         integer
---@return nil
local function maximize(winnr)
  t:defer(function()
    local in_place = dot.state.maximized.get_in_place()
    if in_place ~= nil then
      dot.state.maximized.dispose_in_place(in_place)
    end
  end)
  vim.api.nvim_set_current_win(winnr)
  dot.state.status.set_winnr_command(winnr)
  era.m.maximize.toggle()
end

t:test("maximize enlarges a sidebar pane in its own window and keeps the sidebar it restores to", function()
  local session = open()
  local winnr = assert(session.layout.changes.unstaged.winnr)
  local tabnr = vim.api.nvim_get_current_tabpage()
  local width, height = vim.api.nvim_win_get_width(winnr), vim.api.nvim_win_get_height(winnr)
  local panel_width = dot.context.diffview.panel_width:snapshot()
  local cmdheight = vim.o.cmdheight

  maximize(winnr)
  t.assert_eq(tabnr, vim.api.nvim_get_current_tabpage(), "the pane stays in its tab")
  t.assert_true(vim.api.nvim_win_get_width(winnr) > width, "widened")
  local maximized_height = vim.api.nvim_win_get_height(winnr)
  t.assert_true(maximized_height > height, "heightened")
  vim.api.nvim_exec_autocmds("WinResized", {})
  t.assert_eq(panel_width, dot.context.diffview.panel_width:snapshot(), "the panel width it restores to")
  t.assert_eq(maximized_height, vim.api.nvim_win_get_height(winnr), "the column's proportions wait")

  era.m.maximize.toggle()
  t.assert_same({ width, height }, { vim.api.nvim_win_get_width(winnr), vim.api.nvim_win_get_height(winnr) })
  t.assert_eq(cmdheight, vim.o.cmdheight, "the command line keeps its height")
end)

t:test("hiding a maximized pane restores the sidebar first", function()
  local session = open()
  local lyt = session.layout
  local unstaged_winnr = assert(lyt.changes.unstaged.winnr)
  local width = vim.api.nvim_win_get_width(unstaged_winnr)
  maximize(assert(lyt.history.commits_winnr))

  action.toggle_history(session)
  t.assert_same({ "staged", "unstaged" }, workspace_view.sidebar_panes(lyt))
  t.assert_nil(dot.state.maximized.get_in_place(), "no window maximized")
  t.assert_eq(width, vim.api.nvim_win_get_width(unstaged_winnr), "the sidebar width")
end)

t:run()
