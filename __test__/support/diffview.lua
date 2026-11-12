---@diagnostic disable-next-line: unused-local
local __module_name__ = "__test__.support.diffview" ---@type string

local fs = require("__test__.support.fs")
local git = require("__test__.support.git")
local harness = require("__test__.support.harness")
local treeview = require("__test__.support.treeview")

local M = {}

local function noop() end

---@return stl.t.IKeymap[]
local function no_keymaps()
  return {}
end

---@param context                       table
---@param fields                        table
---@return table
local function assign(context, fields)
  for key, value in pairs(fields) do
    context[key] = value
  end
  return context
end

---A workspace context with every hook a workspace session provides; `fields` replace the defaults.
---@param fields                        table
---@return era.m.diffview.view.workspace.IContext
function M.workspace_context(fields)
  return assign({
    pending_discards = {},
    close = noop,
    get_keymaps = no_keymaps,
    refresh = noop,
    setup_changes = noop,
    setup_history = noop,
    setup_keymaps = noop,
    setup_sbs = noop,
  }, fields)
end

---A commits context with every hook a log session provides, whose previews stay current; `fields` replace
---the defaults.
---@param fields                        table
---@return era.m.diffview.view.commits.IContext
function M.commits_context(fields)
  return assign({
    begin_preview = function()
      return function()
        return true
      end
    end,
    close = noop,
    get_keymaps = no_keymaps,
    render_winline = noop,
    setup_commits = noop,
    setup_filetree = noop,
    setup_keymaps = noop,
    setup_sbs = noop,
  }, fields)
end

---An action module stand-in: every function records its name and arguments in `calls`.
---@return table action
---@return { name: string, args: any[] }[] calls
function M.recorder()
  local calls = {} ---@type { name: string, args: any[] }[]
  local action = setmetatable({}, {
    __index = function(action, name)
      local function record(...)
        calls[#calls + 1] = { name = name, args = { ... } }
      end
      rawset(action, name, record)
      return record
    end,
  })
  return action, calls
end

---The names of `calls`, comma-separated.
---@param calls                         { name: string }[]
---@return string
function M.names(calls)
  local names = {} ---@type string[]
  for i, call in ipairs(calls) do
    names[i] = call.name
  end
  return table.concat(names, ",")
end

---Diffview reads `root` as the workspace for the rest of the case.
---@param t                             __test__.support.Harness
---@param root                          string
---@return string root                  The real path of `root`.
function M.workspace(t, root)
  local realpath = assert(vim.uv.fs_realpath(root))
  t:patch_table(dot.path, "workspace", function()
    return realpath
  end)
  t:patch_table(dot.path, "is_git_repo", function()
    return true
  end)
  return realpath
end

---A repository whose first commit, "base", holds `files`, which Diffview reads as the workspace for the rest of the
---case.
---@param t                             __test__.support.Harness
---@param files                         table<string, string[]> Lines by path.
---@return string root
function M.committed(t, files)
  local root = M.workspace(t, git.repo(t))
  for path, lines in pairs(files) do
    fs.write(root .. "/" .. path, lines)
  end
  git.commit(root, "base")
  return root
end

---A repository with one commit of a.txt, b.txt and d.txt, then a staged addition (c.txt) and an unstaged edit
---(a.txt). Diffview reads it as the workspace for the rest of the case.
---@param t                             __test__.support.Harness
---@return string root
function M.repository(t)
  local root = M.committed(t, { ["a.txt"] = { "one", "two", "three" }, ["b.txt"] = { "bee" }, ["d.txt"] = { "dee" } })
  fs.write(root .. "/a.txt", { "one", "TWO", "three" })
  fs.write(root .. "/c.txt", { "new" })
  git.run(root, { "add", "c.txt" })
  return root
end

---Records the Git commands run through `stl.git.exec.exec_async` for the rest of the case. A command still runs
---unless `respond` answers it with an exit code and stderr.
---@param t                             __test__.support.Harness
---@param respond                       ?fun(args: string[]): integer|nil, string|nil
---@return { args: string[], opts: { cwd: string|nil, stdin: string|nil } }[] calls
function M.record_git(t, respond)
  local calls = {} ---@type { args: string[], opts: { cwd: string|nil, stdin: string|nil } }[]
  local exec_async = stl.git.exec.exec_async
  t:patch_table(stl.git.exec, "exec_async", function(args, opts, callback)
    calls[#calls + 1] = { args = args, opts = opts }
    local code, stderr = nil, nil ---@type integer|nil, string|nil
    if respond then
      code, stderr = respond(args)
    end
    if code == nil then
      return exec_async(args, opts, callback)
    end
    vim.schedule(function()
      callback({}, code, stderr or "")
    end)
  end)
  return calls
end

---The index commands among `calls`: transfers, discards, and the HEAD probe that picks how to unstage.
---@generic T: { args: string[] }
---@param calls                         T[]
---@return T[]
function M.index_calls(calls)
  local writes = { add = true, checkout = true, reset = true, restore = true, rm = true }
  return vim.tbl_filter(function(call)
    local args = call.args
    return writes[args[1]] == true or (args[1] == "rev-parse" and args[#args] == "HEAD^{commit}")
  end, calls)
end

---The NUL-delimited pathspecs `call` passes on stdin.
---@param call                          { opts: { stdin: string|nil } }
---@return string[]
function M.pathspecs(call)
  local input = assert(call.opts.stdin, "pathspec stdin")
  assert(input:sub(-1) == "\0", "pathspec stdin ends with NUL")
  return vim.split(input:sub(1, -2), "\0", { plain = true })
end

---Counts the refreshes requested from `state` for the rest of the case, and those that completed.
---@param t                             __test__.support.Harness
---@param state                         era.m.diffview.view.workspace.State
---@return { requested: integer, completed: integer }
function M.count_refreshes(t, state)
  local count = { requested = 0, completed = 0 }
  local request_refresh = state.request_refresh
  t:patch_table(state, "request_refresh", function(self, callback)
    count.requested = count.requested + 1
    request_refresh(self, function()
      count.completed = count.completed + 1
      if callback then
        callback()
      end
    end)
  end)
  return count
end

---Waits until `count` of the refreshes `count_refreshes` counts have completed.
---@param refreshes                     { completed: integer }
---@param count                         integer
---@return nil
function M.await_refreshes(refreshes, count)
  harness.wait_until(function()
    return refreshes.completed >= count
  end, 10000, "completed refreshes")
end

---The row of `path`, a file or a directory, in the Changes pane of `stage_type`; nil when the pane does not show it.
---@param session                       era.m.diffview.WorkspaceSession
---@param stage_type                    "staged"|"unstaged"
---@param path                          string
---@return integer|nil
function M.row(session, stage_type, path)
  local pane_changes = require("era.m.diffview.pane.changes")
  local bufnr = session.layout.changes[stage_type].bufnr
  if not bufnr or not vim.api.nvim_buf_is_valid(bufnr) then
    return nil
  end
  for lnum = 1, vim.api.nvim_buf_line_count(bufnr) do
    local item = pane_changes.get_item_at_line(bufnr, lnum)
    if item and ((item.entry and item.entry.filepath == path) or (item.type == "directory" and item.uuid == path)) then
      return lnum
    end
  end
end

---Focuses the Changes pane of `stage_type` and puts the cursor on the row of `path`, a file or a directory.
---@param session                       era.m.diffview.WorkspaceSession
---@param stage_type                    "staged"|"unstaged"
---@param path                          string
---@return nil
function M.cursor_on(session, stage_type, path)
  local lnum = M.row(session, stage_type, path)
  if not lnum then
    error(string.format("no %s row for %s", stage_type, path), 2)
  end
  local winnr = session.layout.changes[stage_type].winnr
  vim.api.nvim_set_current_win(winnr)
  vim.api.nvim_win_set_cursor(winnr, { lnum, 0 })
end

---Collapses `dir` in the Changes pane of `stage_type` and waits until the pane no longer shows `inside`, a path
---under it.
---@param t                             __test__.support.Harness
---@param session                       era.m.diffview.WorkspaceSession
---@param stage_type                    "staged"|"unstaged"
---@param dir                           string
---@param inside                        string
---@return nil
function M.collapse(t, session, stage_type, dir, inside)
  session.state:collapse_dir(stage_type, dir)
  t.wait_until(function()
    return M.row(session, stage_type, inside) == nil
  end, 5000, dir .. " collapsed")
end

---Opens the workspace session and waits until History has rendered and the first refresh has applied, selecting the
---first file when there is one, so later previews supersede the initial one; the case closes it.
---@param t                             __test__.support.Harness
---@return era.m.diffview.WorkspaceSession
function M.open_workspace(t)
  local session = assert(require("era.m.diffview.session").open_workspace())
  t:defer(function()
    session:close()
  end)
  local state = session.state
  t.wait_until(function()
    return session.history.state:get_tree("commits"):frame() ~= nil
      and state:is_entries_snapshot_applied()
      and (#state:get_entries() == 0 or state:get_current_entry() ~= nil)
  end, 10000, "rendered History and the first selection")
  return session
end

---Opens a log session and waits until it lists its commits; the case closes it.
---@param t                             __test__.support.Harness
---@param opts                          ?{ layout: integer|nil, path: string|nil }
---@return era.m.diffview.CommitsSession
function M.open_log(t, opts)
  local session = assert(require("era.m.diffview.session").open_log(opts))
  t:defer(function()
    session:close()
  end)
  t.wait_until(function()
    return #session.state:get_commits() > 0
  end, 10000, "log commits")
  return session
end

---The Normal-mode mapping `bufnr` itself has for `lhs`.
---@param bufnr                         integer
---@param lhs                           string
---@return table|nil
function M.mapping(bufnr, lhs)
  local raw = vim.keycode(lhs)
  for _, keymap in ipairs(vim.api.nvim_buf_get_keymap(bufnr, "n")) do
    if keymap.lhsraw == raw or keymap.lhsrawalt == raw then
      return keymap
    end
  end
end

---Opens the left and right side-by-side windows below the current window, each showing a scratch buffer of `lines`,
---for the rest of the case. The focus stays where it was.
---@param t                             __test__.support.Harness
---@param lines                         ?string[]
---@return integer left_winnr
---@return integer right_winnr
function M.sbs_windows(t, lines)
  local left_winnr = t:window(t:buffer(lines), { split = "below", win = vim.api.nvim_get_current_win() })
  return left_winnr, t:window(t:buffer(lines), { split = "below", win = left_winnr })
end

---Shows the panel buffer `bufnr`, which is wiped once no window shows it, in a floating window at the top left of the
---editor for the rest of the case; `enter` focuses the window.
---@param t                             __test__.support.Harness
---@param bufnr                         integer
---@param width                         integer
---@param height                        integer
---@param enter                         ?boolean
---@return integer
local function float(t, bufnr, width, height, enter)
  return t:window(bufnr, { relative = "editor", row = 0, col = 0, width = width, height = height }, enter)
end

---Shows the panel buffer `bufnr`, which is wiped once no window shows it, in a focused floating window 60 columns wide
---and 10 rows high at the top left of the editor for the rest of the case.
---@param t                             __test__.support.Harness
---@param bufnr                         integer
---@return integer
function M.panel_window(t, bufnr)
  return float(t, bufnr, 60, 10, true)
end

---Waits until `owner` shows `count` rows and is ready, then asserts that its buffer has as many lines.
---@param t                             __test__.support.Harness
---@param owner                         era.view.ResultTree
---@param count                         integer
---@return nil
function M.await_rows(t, owner, count)
  t.wait_until(function()
    return owner:linecount() == count
  end, 5000, "native expansion did not reach the surface")
  treeview.await(owner:ready())
  t.assert_eq(count, vim.api.nvim_buf_line_count(owner.view.bufnr))
end

---Publishes `keys` as container rows under the root of `owner`, a root that does not fold.
---@param owner                         era.view.ResultTree
---@param keys                          string[]
---@return nil
function M.populate_tree(owner, keys)
  local root = owner.source.root
  owner.entries[root] = { nodetype = "container", foldable = false }
  for _, key in ipairs(keys) do
    owner.source:insert(root, key, { presentation = { label = key } })
    owner.entries[key] = { nodetype = "container" }
  end
  treeview.publish(owner)
end

---A Changes pane in a 50x10 floating window, focused when `enter` is set, for the rest of the case: a new tree renders
---`entries` with the render `options` there.
---@param t                             __test__.support.Harness
---@param entries                       era.m.diffview.IFileEntry[]
---@param options                       table The render options, which name the pane's `stage_type`.
---@param enter                         ?boolean
---@return era.view.ResultTree owner
---@return { stage_type: string, bufnr: integer, winnr: integer } pane
---@return table plan
function M.changes_pane(t, entries, options, enter)
  local pane_changes = require("era.m.diffview.pane.changes")
  local bufnr = pane_changes.create_buffer(options.stage_type)
  local owner = require("era.m.diffview.pane.tree").new()
  t:defer(function()
    owner:dispose()
  end)
  local winnr = float(t, bufnr, 50, 10, enter)
  local plan = pane_changes.render(entries, options)
  treeview.await(pane_changes.apply_to_buffer(bufnr, plan, owner))
  return owner, { stage_type = options.stage_type, bufnr = bufnr, winnr = winnr }, plan
end

---A Commits pane in a floating window 60 columns wide and `height` rows high, focused when `enter` is set, for the rest
---of the case: a new commits state whose current commit is `current` renders `commits` there as a tree that keeps
---empty directories unfolded.
---@param t                             __test__.support.Harness
---@param commits                       era.m.diffview.ICommit[]
---@param current                       era.m.diffview.ICommit
---@param height                        integer
---@param enter                         ?boolean
---@return table ctx
---@return era.view.ResultTree owner
function M.commits_pane(t, commits, current, height, enter)
  t:patch_table(dot.context.diffview.flag_panel_viewtype, "snapshot", function()
    return "tree"
  end)
  t:patch_table(dot.context.diffview.flag_foldempty, "snapshot", function()
    return false
  end)
  local bufnr = require("era.m.diffview.pane.commits").create_buffer()
  local winnr = float(t, bufnr, 60, height, enter)
  local state = require("era.m.diffview.view.commits.state").State.new(vim.api.nvim_get_current_tabpage(), false)
  t:defer(function()
    state:dispose()
  end)
  state:set_commits(commits)
  state:set_current_commit(current)
  local ctx = M.commits_context({
    state = state,
    layout = { tabnr = state.tabnr, layout_type = 2, commits_bufnr = bufnr, commits_winnr = winnr },
  })
  treeview.await(require("era.m.diffview.view.commits.view").render_commits(ctx))
  return ctx, state:get_tree("commits")
end

---A Commits pane of one current commit, "review", with `files`, in a focused floating window 10 rows high, as
---`commits_pane` makes it.
---@param t                             __test__.support.Harness
---@param files                         ?era.m.diffview.IFileEntry[]
---@return table ctx
---@return era.view.ResultTree owner
function M.review_pane(t, files)
  local commit = { hash = "review", abbrev_hash = "review", author = "A", date = 0, message = "review", files = files }
  return M.commits_pane(t, { commit }, commit, 10, true)
end

return M
