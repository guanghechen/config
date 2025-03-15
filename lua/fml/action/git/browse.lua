local __module_name__ = "fml.action.git" ---@type string

local select = require("fml.fn.select")

---@alias fml.action.git.browse.TargetScope
---|"branch"
---|"file"
---|"repo"

---@class fml.action.git.browse.IRemote
---@field public name                   string
---@field public url                    string

---@class fml.action.git.browse
local config = {
  -- patterns to transform remotes to an actual URL
  -- stylua: ignore start
  remote_patterns = {
    { "^(https?://.*)%.git$"              , "%1" },
    { "^git@(.+):(.+)%.git$"              , "https://%1/%2" },
    { "^git@(.+):(.+)$"                   , "https://%1/%2" },
    { "^git@(.+)/(.+)$"                   , "https://%1/%2" },
    { "^org%-%d+@(.+):(.+)%.git$"         , "https://%1/%2" },
    { "^ssh://git@(.*)$"                  , "https://%1" },
    { "^ssh://([^:/]+)(:%d+)/(.*)$"       , "https://%1/%3" },
    { "^ssh://([^/]+)/(.*)$"              , "https://%1/%2" },
    { "ssh%.dev%.azure%.com/v3/(.*)/(.*)$", "dev.azure.com/%1/_git/%2" },
    { "^https://%w*@(.*)"                 , "https://%1" },
    { "^git@(.*)"                         , "https://%1" },
    { ":%d+"                              , "" },
    { "%.git$"                            , "" },
  },
  -- stylua: ignore end
  url_patterns = {
    ["github%.com"] = {
      branch = "/tree/{branch}",
      file = "/blob/{branch}/{file}#L{line_start}-L{line_end}",
      permalink = "/blob/{commit}/{file}#L{line_start}-L{line_end}",
      commit = "/commit/{commit}",
    },
    ["gitlab%.com"] = {
      branch = "/-/tree/{branch}",
      file = "/-/blob/{branch}/{file}#L{line_start}-L{line_end}",
      permalink = "/-/blob/{commit}/{file}#L{line_start}-L{line_end}",
      commit = "/-/commit/{commit}",
    },
    ["bitbucket%.org"] = {
      branch = "/src/{branch}",
      file = "/src/{branch}/{file}#lines-{line_start}-L{line_end}",
      permalink = "/src/{commit}/{file}#lines-{line_start}-L{line_end}",
      commit = "/commits/{commit}",
    },
    ["git.sr.ht"] = {
      branch = "/tree/{branch}",
      file = "/tree/{branch}/item/{file}",
      permalink = "/tree/{commit}/item/{file}#L{line_start}",
      commit = "/commit/{commit}",
    }
  },
}

---@param cmd                           string[]
---@param err                           string
---@return string[]
local function system(cmd, err)
  local proc = vim.fn.system(cmd)
  if vim.v.shell_error ~= 0 then
    eve.reporter.error({
      from = __module_name__,
      subject = 'browse',
      message = err,
      details = { error = err, proc = proc }
    })
    error(err)
  end
  return vim.split(vim.trim(proc), "\n", { plain = true })
end

---@param filename                      string
---@param lnum                          integer
local function get_last_commit_hash(filename, lnum)
  local command = string.format("git blame -slL %d,%d %s", lnum, lnum, filename)
  local handle = io.popen(command)

  if not handle then
    eve.reporter.error({
      from = __module_name__,
      subject = 'browse',
      message = "Failed to run git command to get last commit hash of the filename with specified line number",
    })
    return
  end

  local output = handle:read("*a")
  handle:close()

  -- If output is empty, return nil (no commit history found for that line)
  if output == "" then
    return nil
  end

  -- Extract the commit hash (first part of the output line)
  local commit_hash = output:match("^%S+")
  if commit_hash == "0000000000000000000000000000000000000000" then
    return nil
  end
  return commit_hash
end

---@return string
local function get_git_branch_or_commit()
  local command = eve.env.IS_WIN
  and 'git rev-parse --abbrev-ref HEAD 2>$null'
  or 'git rev-parse --abbrev-ref HEAD 2>/dev/null'

  -- Run the git command to get the branch name
  local handle = io.popen(command)
  if not handle then
    eve.reporter.error({
      from = __module_name__,
      subject = 'browse',
      message = "Failed to run git command to get branch",
    })
    return "HEAD"
  end

  local branch = handle:read('*a')
  handle:close()

  if branch and branch ~= nil then
    branch = branch:match("^%s*(.-)%s*$")
  end

  -- If not on a branch, try to get the commit hash
  if branch == '' or branch == 'HEAD' then
    command = eve.env.IS_WIN
    and 'git rev-parse HEAD 2>$null'
    or 'git rev-parse HEAD 2>/dev/null'

    handle = io.popen(command)
    if not handle then
      eve.reporter.error({
        from = __module_name__,
        subject = 'browse',
        message = "Failed to run git command to get commit hash",
      })
      return "HEAD"
    end

    branch = handle:read('*a')
    handle:close()
  end

  if branch and branch ~= '' then
    return branch:match("^%s*(.-)%s*$")
  end
  return "HEAD"
end

---@return string|nil
local function get_file_line()
  local mode = vim.fn.mode()
  if  mode ~= "v" and mode ~= "V" then
    vim.fn.line(".")
  end

  local start_line = vim.fn.line("v")
  local end_line = vim.fn.line(".")

  -- Ensure start_line is always the smaller number
  if start_line > end_line then
    start_line, end_line = end_line, start_line
  end
  return start_line .. "-L" .. end_line
end

---@param remote                        string
---@return string
local function get_repo(remote)
  local ret = remote ---@type string
  for _, pattern in ipairs(config.remote_patterns) do
    ret = ret:gsub(pattern[1], pattern[2]) --[[@as string]]
  end
  return ret:find("https://") == 1 and ret or ("https://%s"):format(ret)
end

---@param repo                          string
---@param what                          fml.action.git.browse.TargetScope
local function get_url(repo, what)
  for remote, patterns in pairs(config.url_patterns) do
    if repo:find(remote) then
      return patterns[what] and (repo .. patterns[what]) or repo
    end
  end
  return repo
end

---@param remote                        fml.action.git.browse.IRemote
local function open_remote(remote)
  if remote then
    eve.reporter.info({
      from = __module_name__,
      subject = 'browse',
      message = "Opening " .. "[" .. remote.name.. "]" .. "(" ..remote.url .. ")",
    })
    vim.ui.open(remote.url)
  end
end



---@class fml.action.git
local M = {}

---@return nil
function M.browse()
  local bufnr_sourcefile = eve.state.editor.get_bufnr_sourcefile() ---@type integer|nil
  if bufnr_sourcefile == nil then
    return
  end

  local workspace = eve.path.workspace() ---@type string
  local filepath = vim.api.nvim_buf_get_name(bufnr_sourcefile) ---@type string|nil
  filepath = filepath ~= nil and eve.path.is_under(workspace, filepath) and eve.path.relative(workspace, filepath, true) or nil

  local remotes = {} ---@type fml.action.git.browse.IRemote[]
  local fields = {
    branch = get_git_branch_or_commit(),
    file = filepath,
    line = filepath and get_file_line(),
  }

  local scope = fields.file and "file" or (fields.branch and "branch" or "repo") ---@type fml.action.git.browse.TargetScope
  for _, line in ipairs(system({ "git", "-C", workspace, "remote", "-v" }, "Failed to get git remotes")) do
    local name, remote_url = line:match("(%S+)%s+(%S+)%s+%(fetch%)")
    if name and remote_url then
      local repo = get_repo(remote_url)
      if repo then
        ---@type fml.action.git.browse.IRemote
        local remote = {
          name = name,
          url = get_url(repo, scope):gsub("(%b{})", function(key)
            return fields[key:sub(2, -2)] or key
          end),
        }
        table.insert(remotes, remote)
      end
    end
  end

  if #remotes == 0 then
    eve.reporter.error({
      from = __module_name__,
      subject = 'browse',
      message = "No git remotes found",
      details = { what = scope, workspace = workspace, filepath = filepath }
    })
    return
  end

  if #remotes == 1 then
    open_remote(remotes[1])
    return
  end

  select({
    dimension = {
      row = 5,
      width = 80,
    },
    flag_fuzzy = true,
    flag_regex = false,
    input = eve.col.Observable.from_value(""),
    multiple = false,
    title = "Select remote to browse",
    fetch_items = function()
      local items = {} ---@type fml.ux.select.IItem[]
      for _, remote in ipairs(remotes) do
        local item = {uuid = remote.url, text = remote.name .. " | " .. remote.url, data = remote }---@type fml.ux.select.IItem
        table.insert(items, item)
      end
      return items
    end,
    on_confirm = function(widget, items)
      if #items == 1 then
        widget:close()
        local item = items[1] ---@type fml.ux.select.IItem
        open_remote(item.data)
      end
    end
  })
end

return M

