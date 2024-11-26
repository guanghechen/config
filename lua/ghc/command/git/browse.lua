---@alias ghc.command.git.browse.TargetType "branch" |"file" |"repo"

---@class ghc.command.git.browse.IRemote
---@field public name                   string
---@field public url                    string

---@class ghc.command.git.browse
local config = {
  what = "file", ---@type ghc.command.git.browse.TargetType
  -- patterns to transform remotes to an actual URL
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
      from = "ghc.command.git.browser",
      message = err,
      details = { error = err, proc = proc }
    })
    error(err)
  end
  return vim.split(vim.trim(proc), "\n")
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
---@param what                          ghc.command.git.browse.TargetType
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
      from = "ghc.command.git.browse",
      message = "Opening " .. "[" .. remote.name.. "]" .. "(" ..remote.url .. ")",
    })
    vim.ui.open(remote.url)
  end
end

---@return nil
local function open()
  local workspace  = eve.path.workspace() ---@type string
  local remotes = {} ---@type ghc.command.git.browse.IRemote[]

  local filepath = vim.api.nvim_buf_get_name(0) ---@type string|nil
  filepath = filepath and (vim.uv.fs_stat(filepath) or {}).type == "file" and vim.fs.normalize(filepath) or nil

  local fields = {
    branch = system({ "git", "-C", workspace, "rev-parse", "--abbrev-ref", "HEAD" }, "Failed to get current branch")[1],
    file = filepath and system({ "git", "-C", workspace, "ls-files", "--full-name", filepath }, "Failed to get git file path")[1],
    line = nil,
  }

  -- Get visual selection range if in visual mode
  if vim.fn.mode() == "v" or vim.fn.mode() == "V" then
    local start_line = vim.fn.line("v")
    local end_line = vim.fn.line(".")
    -- Ensure start_line is always the smaller number
    if start_line > end_line then
      start_line, end_line = end_line, start_line
    end
    fields.line = filepath and start_line .. "-L" .. end_line
  else
    fields.line = filepath and vim.fn.line(".")
  end

  local what = config.what ---@type ghc.command.git.browse.TargetType
  what = what == "file" and not fields.file and "branch" or what
  what = what == "branch" and not fields.branch and "repo" or what

  for _, line in ipairs(system({ "git", "-C", workspace, "remote", "-v" }, "Failed to get git remotes")) do
    local name, remote_url = line:match("(%S+)%s+(%S+)%s+%(fetch%)")
    if name and remote_url then
      local repo = get_repo(remote_url)
      if repo then
        ---@type ghc.command.git.browse.IRemote
        local remote = {
          name = name,
          url = get_url(repo, what):gsub("(%b{})", function(key)
            return fields[key:sub(2, -2)] or key
          end),
        }
        table.insert(remotes, remote)
      end
    end
  end

  if #remotes == 0 then
    eve.reporter.error({
      from = "ghc.command.git.browse",
      message = "No git remotes found",
      details = { what = what, workspace = workspace, filepath = filepath }
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
    input = eve.c.Observable.from_value(""),
    dimension = {
      row = 5,
      width = 80,
    },
    fetch_items = function()
      local items = {} ---@type t.fml.ux.select.IItem[]
      for _, remote in ipairs(remotes) do
        local item = {uuid = remote.url, text = remote.name .. " | " .. remote.url, data = remote }---@type t.fml.ux.select.IItem
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

local uuids = eve.commander.uuids ---@type eve.std.commander.uuids

eve.commander
.register({
  uuid = uuids.git_browse ,
  desc = "git: browse",
  action = function()
    open()
  end,
})

