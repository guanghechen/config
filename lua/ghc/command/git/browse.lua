local __module_name__ = "ghc.command.git.browser" ---@type string

local constant = require("eve.builtin.constant")
local Observable = require("eve.collection.observable")

---@alias ghc.command.git.browse.TargetScope
---|"branch"
---|"file"
---|"repo"

---@class ghc.command.git.browse.IRemote
---@field public name                   string
---@field public url                    string

---@class ghc.command.git.browse
local config = {
  -- patterns to transform remotes to an actual URL
  -- stylua: ignore start
  remote_patterns = {
    { "^(https?://.*)%.git$"              , "%1" },
    { "^git@(.+):(.+)%.git$"              , "https://%1/%2" },
    { "^git@(.+):(.+)$"                   , "https://%1/%2" },
    { "^git@(.+)/(.+)$"                   , "https://%1/%2" },
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
      file = "/blob/{branch}/{file}#L{line}",
    },
    ["gitlab%.com"] = {
      branch = "/-/tree/{branch}",
      file = "/-/blob/{branch}/{file}#L{line}",
    },
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
      message = err,
      details = { error = err, proc = proc }
    })
    error(err)
  end
  return vim.split(vim.trim(proc), "\n")
end

---@param filename                      string
---@param lnum                          integer
local function get_last_commit_hash(filename, lnum)
  local command = string.format("git blame -slL %d,%d %s", lnum, lnum, filename)
  local handle = io.popen(command)

  if not handle then
    eve.reporter.error({
      from = __module_name__,
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
  local command = constant.IS_WIN
    and 'git rev-parse --abbrev-ref HEAD 2>$null'
    or 'git rev-parse --abbrev-ref HEAD 2>/dev/null'

  -- Run the git command to get the branch name
  local handle = io.popen(command)
  if not handle then
    eve.reporter.error({
      from = __module_name__,
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
    command = constant.IS_WIN
      and 'git rev-parse HEAD 2>$null'
      or 'git rev-parse HEAD 2>/dev/null'

    handle = io.popen(command)
    if not handle then
      eve.reporter.error({
        from = __module_name__,
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
local function get_filepath()
  local workspace  = eve.path.workspace() ---@type string
  local filepath = vim.api.nvim_buf_get_name(0) ---@type string|nil

  if filepath == nil then
    return nil
  end

  if eve.path.is_under(workspace, filepath) then
    return  eve.path.relative(workspace, filepath, true) ---@type string
  end

  return  nil
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
---@param what                          ghc.command.git.browse.TargetScope
local function get_url(repo, what)
  for remote, patterns in pairs(config.url_patterns) do
    if repo:find(remote) then
      return patterns[what] and (repo .. patterns[what]) or repo
    end
  end
  return repo
end

---@param remote                        ghc.command.git.browse.IRemote
local function open_remote(remote)
  if remote then
    eve.reporter.info({
      from = __module_name__,
      message = "Opening " .. "[" .. remote.name.. "]" .. "(" ..remote.url .. ")",
    })
    vim.ui.open(remote.url)
  end
end

---@return nil
local function open()
  local workspace  = eve.path.workspace() ---@type string
  local filepath = get_filepath() ---@type string|nil
  local remotes = {} ---@type ghc.command.git.browse.IRemote[]
  local fields = {
    branch = get_git_branch_or_commit(),
    file = filepath,
    line = filepath and get_file_line(),
  }

  local scope = fields.file and "file" or (fields.branch and "branch" or "repo") ---@type ghc.command.git.browse.TargetScope
  for _, line in ipairs(system({ "git", "-C", workspace, "remote", "-v" }, "Failed to get git remotes")) do
    local name, remote_url = line:match("(%S+)%s+(%S+)%s+%(fetch%)")
    if name and remote_url then
      local repo = get_repo(remote_url)
      if repo then
        ---@type ghc.command.git.browse.IRemote
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
      message = "No git remotes found",
      details = { what = scope, workspace = workspace, filepath = filepath }
    })
    return
  end

  if #remotes == 1 then
    open_remote(remotes[1])
    return
  end

  fml.fn.select({
    title = "Select remote to browse",
    flag_fuzzy = true,
    flag_regex = false,
    input = Observable.from_value(""),
    dimension = {
      row = 5,
      width = 80,
    },
    fetch_items = function()
      local items = {} ---@type fml.t.ux.select.IItem[]
      for _, remote in ipairs(remotes) do
        local item = {uuid = remote.url, text = remote.name .. " | " .. remote.url, data = remote }---@type fml.t.ux.select.IItem
        table.insert(items, item)
      end
      return items
    end,
    on_confirm = function(item)
      open_remote(item.data)
      return "close"
    end
  })
end

local uuids = eve.commander.uuids ---@type eve.builtin.commander.uuids

eve.commander
.register({
  uuid = uuids.git_browse ,
  desc = "git: browse",
  action = function()
    open()
  end,
})

