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

---A repository with one commit of a.txt, b.txt and d.txt, then a staged addition (c.txt) and an unstaged edit
---(a.txt). Diffview reads it as the workspace for the rest of the case.
---@param t                             __test__.support.Harness
---@return string root
function M.repository(t)
  local git = require("__test__.support.git")
  local root = assert(vim.uv.fs_realpath(git.repo(t)))
  vim.fn.writefile({ "one", "two", "three" }, root .. "/a.txt")
  vim.fn.writefile({ "bee" }, root .. "/b.txt")
  vim.fn.writefile({ "dee" }, root .. "/d.txt")
  git.run(root, { "add", "." })
  git.run(root, { "commit", "-q", "-m", "first" })
  vim.fn.writefile({ "one", "TWO", "three" }, root .. "/a.txt")
  vim.fn.writefile({ "new" }, root .. "/c.txt")
  git.run(root, { "add", "c.txt" })
  t:patch_table(dot.path, "workspace", function()
    return root
  end)
  t:patch_table(dot.path, "is_git_repo", function()
    return true
  end)
  return root
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
