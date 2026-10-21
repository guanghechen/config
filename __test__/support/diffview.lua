---@diagnostic disable-next-line: unused-local
local __module_name__ = "__test__.support.diffview" ---@type string

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

---Writes `lines` to `path` under `root`, creating its directories.
---@param root                          string
---@param path                          string
---@param lines                         string[]
---@return nil
function M.write(root, path, lines)
  vim.fn.mkdir(vim.fs.dirname(root .. "/" .. path), "p")
  vim.fn.writefile(lines, root .. "/" .. path)
end

---A repository whose first commit holds `files`, which Diffview reads as the workspace for the rest of the case.
---@param t                             __test__.support.Harness
---@param files                         table<string, string[]> Lines by path.
---@return string root
function M.committed(t, files)
  local git = require("__test__.support.git")
  local root = M.workspace(t, git.repo(t))
  for path, lines in pairs(files) do
    M.write(root, path, lines)
  end
  git.run(root, { "add", "." })
  git.run(root, { "commit", "-q", "-m", "base" })
  return root
end

---A repository with one commit of a.txt, b.txt and d.txt, then a staged addition (c.txt) and an unstaged edit
---(a.txt). Diffview reads it as the workspace for the rest of the case.
---@param t                             __test__.support.Harness
---@return string root
function M.repository(t)
  local git = require("__test__.support.git")
  local root = M.committed(t, { ["a.txt"] = { "one", "two", "three" }, ["b.txt"] = { "bee" }, ["d.txt"] = { "dee" } })
  M.write(root, "a.txt", { "one", "TWO", "three" })
  M.write(root, "c.txt", { "new" })
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
  return vim.tbl_filter(function(call)
    local args = call.args
    return args[1] == "--literal-pathspecs" or (args[1] == "rev-parse" and args[#args] == "HEAD^{commit}")
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

---Focuses the Changes pane of `stage_type` and puts the cursor on the row of `path`, a file or a directory.
---@param session                       era.m.diffview.WorkspaceSession
---@param stage_type                    "staged"|"unstaged"
---@param path                          string
---@return nil
function M.cursor_on(session, stage_type, path)
  local pane_changes = require("era.m.diffview.pane.changes")
  local pane = session.layout.changes[stage_type]
  vim.api.nvim_set_current_win(pane.winnr)
  for lnum = 1, vim.api.nvim_buf_line_count(pane.bufnr) do
    local item = pane_changes.get_item_at_line(pane.bufnr, lnum)
    if item and ((item.entry and item.entry.filepath == path) or (item.type == "directory" and item.uuid == path)) then
      vim.api.nvim_win_set_cursor(pane.winnr, { lnum, 0 })
      return
    end
  end
  error(string.format("no %s row for %s", stage_type, path), 2)
end

---Opens the workspace session and waits until History has rendered and the first file is selected, so later
---previews supersede the initial one; the case closes it.
---@param t                             __test__.support.Harness
---@return era.m.diffview.WorkspaceSession
function M.open_workspace(t)
  local session = assert(require("era.m.diffview.session").open_workspace())
  t:defer(function()
    session:close()
  end)
  t.wait_until(function()
    return session.history.state:get_tree("commits"):frame() ~= nil and session.state:get_current_entry() ~= nil
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

return M
