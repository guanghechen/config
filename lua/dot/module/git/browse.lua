local REMOTE_PATTERNS = {
  { "^(https?://.*)%.git$", "%1" },
  { "^git@(.+):(.+)%.git$", "https://%1/%2" },
  { "^git@(.+):(.+)$", "https://%1/%2" },
  { "^git@(.+)/(.+)$", "https://%1/%2" },
  { "^org%-%d+@(.+):(.+)%.git$", "https://%1/%2" },
  { "^ssh://git@(.*)$", "https://%1" },
  { "^ssh://([^:/]+)(:%d+)/(.*)$", "https://%1/%3" },
  { "^ssh://([^/]+)/(.*)$", "https://%1/%2" },
  { "ssh%.dev%.azure%.com/v3/(.*)/(.*)$", "dev.azure.com/%1/_git/%2" },
  { "^https://%w*@(.*)", "https://%1" },
  { "^git@(.*)", "https://%1" },
  { ":%d+", "" },
  { "%.git$", "" },
}

local URL_PATTERNS = {
  ["github%.com"] = {
    branch = "/tree/{branch}",
    file = "/blob/{branch}/{file}#L{line_start}-L{line_end}",
    permalink = "/blob/{commit}/{file}#L{line_start}-L{line_end}",
    commit = "/commit/{commit}",
  },
  ["gitlab%.com"] = {
    branch = "/-/tree/{branch}",
    file = "/-/blob/{branch}/{file}#L{line_start}-{line_end}",
    permalink = "/-/blob/{commit}/{file}#L{line_start}-{line_end}",
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
  },
}

---@class dot.module.git.browse
local M = {}

---@param opts                       { cwd: string|nil, file: string|nil, branch: string|nil, commit: string|nil, line_start: integer|nil, line_end: integer|nil, scope: string|nil }|nil
---@return table
function M.build_fields(opts)
  opts = opts or {}
  local cwd = dot.path.normalize(opts.cwd or dot.path.cwd())

  local function run(args)
    local lines, code = dot.git.cmd.run_sync(args, { cwd = cwd })
    if code ~= 0 or type(lines) ~= "table" then
      return nil
    end
    return lines
  end

  local line_start = opts.line_start or 1
  local line_end = opts.line_end or line_start

  local branch = opts.branch
  if branch == nil or #branch == 0 then
    local lines = run({ "rev-parse", "--abbrev-ref", "HEAD" })
    if lines ~= nil and lines[1] ~= nil then
      if lines[1] == "HEAD" then
        local sha = run({ "rev-parse", "HEAD" })
        branch = sha and sha[1] or nil
      else
        branch = lines[1]
      end
    end
  end

  local commit = opts.commit
  if commit and (#commit < 7 or not commit:match("^[a-fA-F0-9]+$")) then
    commit = nil
  end

  local file = opts.file
  if file and #file > 0 then
    local lines = run({ "ls-files", "--full-name", file })
    if lines ~= nil and lines[1] ~= nil and lines[1] ~= "" then
      file = lines[1]
    else
      file = nil
    end
  end

  local scope = opts.scope or "file"
  if scope == "commit" and not commit then
    scope = "file"
  end
  if scope == "permalink" and not commit and file then
    local lines = run({ "log", "-n", "1", "--pretty=format:%H", "--", file })
    commit = lines and lines[1] or nil
    if not commit then
      scope = "file"
    end
  end
  if not file and scope ~= "commit" then
    scope = "branch"
  end
  if not branch then
    scope = "repo"
  end

  return {
    cwd = cwd,
    scope = scope,
    branch = branch,
    commit = commit,
    file = file,
    line_start = line_start,
    line_end = line_end,
  }
end

---@param fields                      table
---@return table<string, string>[]
function M.get_remotes(fields)
  local lines, code = dot.git.cmd.run_sync({ "remote", "-v" }, { cwd = fields.cwd })
  if code ~= 0 or type(lines) ~= "table" then
    return {}
  end

  local function repo_url(remote)
    local url = remote
    for _, pattern in ipairs(REMOTE_PATTERNS) do
      url = url:gsub(pattern[1], pattern[2])
    end
    if url:find("https://") == 1 then
      return url
    end
    return "https://" .. url
  end

  local function scoped_url(repo, scope)
    for host, patterns in pairs(URL_PATTERNS) do
      if repo:find(host) then
        local pattern = patterns[scope]
        if type(pattern) == "string" then
          return repo .. pattern:gsub("(%b{})", function(key)
            return fields[key:sub(2, -2)] or key
          end)
        elseif type(pattern) == "function" then
          return repo .. pattern(fields)
        end
      end
    end
    return repo
  end

  local remotes = {}
  for _, line in ipairs(lines) do
    local name, remote = line:match("(%S+)%s+(%S+)%s+%(fetch%)")
    if name and remote then
      local repo = repo_url(remote)
      remotes[#remotes + 1] = { name = name, url = scoped_url(repo, fields.scope) }
    end
  end
  return remotes
end

---@param remote                     { name: string, url: string }|nil
function M.open_remote(remote)
  if remote and remote.url then
    vim.ui.open(remote.url)
  end
end

---@param opts                       dot.module.git.browse.IOpenOpts|nil
function M.open(opts)
  opts = opts or {}

  local bufnr = vim.api.nvim_get_current_buf() ---@type integer
  local filepath = vim.api.nvim_buf_get_name(bufnr) ---@type string|nil
  filepath = filepath ~= "" and dot.path.normalize(filepath) or nil
  local stat = filepath and vim.uv.fs_stat(filepath) or nil
  local is_file = stat and stat.type == "file"

  local cwd = (is_file and filepath) and vim.fn.fnamemodify(filepath, ":h") or dot.path.cwd()
  local git_file = (is_file and filepath) and dot.path.relative(cwd, filepath) or nil

  local line_start = opts.line_start ---@type integer|nil
  local line_end = opts.line_end ---@type integer|nil
  if line_start == nil or line_end == nil then
    if vim.fn.mode():find("[vV]") then
      local s, e = ark.vim.buf.retrieve_visual_lnum_range()
      line_start = s
      line_end = e
    else
      local winnr = vim.api.nvim_get_current_win() ---@type integer
      line_start = vim.api.nvim_win_get_cursor(winnr)[1]
      line_end = line_start
    end
  end

  local commit = opts.commit ---@type string|nil
  if not commit then
    local word = vim.fn.expand("<cword>") ---@type string
    if word and #word >= 7 and word:match("^[a-fA-F0-9]+$") then
      commit = word
    end
  end

  local fields = M.build_fields({
    cwd = cwd,
    file = git_file,
    branch = opts.branch,
    commit = commit,
    line_start = line_start,
    line_end = line_end,
    scope = opts.what,
  })

  local remotes = M.get_remotes(fields)
  if #remotes == 0 then
    stl.reporter.error({
      from = "dot.module.git.browse",
      subject = "open",
      message = "No git remotes found",
      details = { what = fields.scope, cwd = cwd, filepath = filepath },
    })
    return
  end

  if #remotes == 1 then
    M.open_remote(remotes[1])
    return
  end

  local max_name_width = 0 ---@type integer
  for _, remote in ipairs(remotes) do
    max_name_width = math.max(max_name_width, vim.api.nvim_strwidth(remote.name))
  end

  vim.ui.select(remotes, {
    name = "dot.module.git.browse",
    prompt = "Select remote to browse",
    format_item = function(remote)
      local padded_name = ark.string.pad_end(remote.name, max_name_width, " ")
      return padded_name .. " | " .. remote.url
    end,
  }, function(choice)
    if choice then
      M.open_remote(choice)
    end
  end)
end

return M
