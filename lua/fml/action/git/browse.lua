---@see https://github.com/folke/snacks.nvim/tree/fe7cfe9800a182274d0f868a74b7263b8c0c020b/lua/snacks/gitbrowse.lua

local __module_name__ = "fml.action.git.browse" ---@type string

---@alias fml.action.git.browse.TargetScope
---| "branch"
---| "commit"
---| "file"
---| "permalink"
---| "repo"

---@class fml.action.git.browse.IRemote
---@field public name                   string
---@field public url                    string

---@class fml.action.git.browse.IFields
---@field public branch                 string|nil
---@field public commit                 string|nil
---@field public file                   string|nil
---@field public line_start             integer|nil
---@field public line_end               integer|nil
---@field public line_count             integer|nil

---@class fml.action.git.browse
local config = {
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
  ---@type table<string, table<string, string|fun(fields:fml.action.git.browse.IFields):string>>
  url_patterns = {
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
  },
}

---@param cmd                           string[]
---@param cwd                           string
---@param err                           string
---@return string[]|nil
local function system(cmd, cwd, err)
  table.insert(cmd, 2, "-C")
  table.insert(cmd, 3, cwd)
  local proc = vim.fn.system(cmd)
  if vim.v.shell_error ~= 0 then
    std.reporter.error({
      from = __module_name__,
      subject = "browse",
      message = err,
      details = { error = err, proc = proc },
    })
    return nil
  end
  return vim.split(vim.trim(proc), "\n", { plain = true })
end

---@param hash                          string
---@param cwd                           string
---@return boolean
local function is_valid_commit_hash(hash, cwd)
  if not (hash:match("^[a-fA-F0-9]+$") and #hash >= 7) then
    return false
  end
  local result = system({ "git", "rev-parse", "--verify", hash }, cwd, "Invalid commit hash")
  return result ~= nil
end

---@param cwd                           string
---@return string|nil
local function get_branch(cwd)
  local result = system({ "git", "rev-parse", "--abbrev-ref", "HEAD" }, cwd, "Failed to get current branch")
  if result and result[1] and result[1] ~= "" then
    local branch = result[1]
    if branch == "HEAD" then
      result = system({ "git", "rev-parse", "HEAD" }, cwd, "Failed to get commit hash")
      return result and result[1] or nil
    end
    return branch
  end
  return nil
end

---@param file                          string
---@param cwd                           string
---@return string|nil
local function get_git_file_path(file, cwd)
  local result = system({ "git", "ls-files", "--full-name", file }, cwd, "Failed to get git file path")
  return result and result[1] or nil
end

---@param file                          string
---@param cwd                           string
---@return string|nil
local function get_file_commit(file, cwd)
  local result = system({ "git", "log", "-n", "1", "--pretty=format:%H", "--", file }, cwd, "Failed to get latest commit of file")
  return result and result[1] or nil
end

---@param bufnr                         integer
---@return integer, integer
local function get_line_range(bufnr)
  local line_start, line_end ---@type integer, integer
  local mode = vim.fn.mode()

  if mode:find("[vV]") then
    vim.api.nvim_feedkeys(":", "nx", false)
    line_start = vim.api.nvim_buf_get_mark(bufnr, "<")[1]
    line_end = vim.api.nvim_buf_get_mark(bufnr, ">")[1]
    vim.api.nvim_feedkeys("gv", "nx", false)
    if line_start > line_end then
      line_start, line_end = line_end, line_start
    end
  else
    local current_line = vim.fn.line(".")
    line_start = current_line
    line_end = current_line
  end

  return line_start, line_end
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
---@param fields                        fml.action.git.browse.IFields
---@return string
local function get_url(repo, what, fields)
  for remote, patterns in pairs(config.url_patterns) do
    if repo:find(remote) then
      local pattern = patterns[what]
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

---@param remote                        fml.action.git.browse.IRemote
local function open_remote(remote)
  if remote then
    std.reporter.info({
      from = __module_name__,
      subject = "browse",
      message = "Opening [" .. remote.name .. "](" .. remote.url .. ")",
    })
    vim.ui.open(remote.url)
  end
end

---@class fml.action.git.browse.IOptions
---@field public what                   fml.action.git.browse.TargetScope|nil
---@field public branch                 string|nil
---@field public commit                 string|nil
---@field public line_start             integer|nil
---@field public line_end               integer|nil

---@class fml.action.git
local M = {}

---@param opts                          fml.action.git.browse.IOptions|nil
---@return nil
function M.browse(opts)
  opts = opts or {}

  local tabnr = vim.api.nvim_get_current_tabpage() ---@type integer
  local bufnr = eve.tab.retrieve_bufnr_sourcefile(tabnr) ---@type integer|nil
  if bufnr == nil then
    return
  end

  local filepath = vim.api.nvim_buf_get_name(bufnr) ---@type string|nil
  filepath = filepath ~= "" and std.path.normalize(filepath) or nil
  local stat = filepath and vim.uv.fs_stat(filepath) or nil
  local is_file = stat and stat.type == "file" or false

  local cwd = is_file and vim.fn.fnamemodify(filepath --[[@as string]], ":h") or std.path.cwd()

  local git_file = is_file and get_git_file_path(filepath --[[@as string]], cwd) or nil

  local line_start, line_end ---@type integer|nil, integer|nil
  if opts.line_start then
    line_start = opts.line_start
    line_end = opts.line_end or opts.line_start
  else
    line_start, line_end = get_line_range(bufnr)
  end

  ---@type fml.action.git.browse.IFields
  local fields = {
    branch = opts.branch or get_branch(cwd),
    file = git_file,
    line_start = line_start,
    line_end = line_end,
    line_count = line_end - line_start + 1,
    commit = opts.commit,
  }

  if not fields.commit then
    local word = vim.fn.expand("<cword>")
    if is_valid_commit_hash(word, cwd) then
      fields.commit = word
    end
  end

  ---@type fml.action.git.browse.TargetScope
  local scope = opts.what or "file"

  if not fields.commit and scope == "commit" then
    scope = "file"
  end
  if not fields.commit and scope == "permalink" then
    fields.commit = filepath and get_file_commit(filepath --[[@as string]], cwd) or nil
    if not fields.commit then
      scope = "file"
    end
  end
  if not fields.file then
    scope = "branch"
  end
  if not fields.branch then
    scope = "repo"
  end

  local remotes_output = system({ "git", "remote", "-v" }, cwd, "Failed to get git remotes")
  if not remotes_output then
    return
  end

  local remotes = {} ---@type fml.action.git.browse.IRemote[]
  for _, line in ipairs(remotes_output) do
    local name, remote_url = line:match("(%S+)%s+(%S+)%s+%(fetch%)")
    if name and remote_url then
      local repo = get_repo(remote_url)
      if repo then
        ---@type fml.action.git.browse.IRemote
        local remote = {
          name = name,
          url = get_url(repo, scope, fields),
        }
        table.insert(remotes, remote)
      end
    end
  end

  if #remotes == 0 then
    std.reporter.error({
      from = __module_name__,
      subject = "browse",
      message = "No git remotes found",
      details = { what = scope, cwd = cwd, filepath = filepath },
    })
    return
  end

  if #remotes == 1 then
    open_remote(remotes[1])
    return
  end

  local max_name_width = 0 ---@type integer
  for _, remote in ipairs(remotes) do
    max_name_width = math.max(max_name_width, vim.api.nvim_strwidth(remote.name))
  end

  vim.ui.select(remotes, {
    name = __module_name__,
    prompt = "Select remote to browse",
    dimension = {
      row = 5,
      width = 80,
    },
    format_item = function(remote)
      local padded_name = std.string.pad_end(remote.name, max_name_width, " ")
      return padded_name .. " │ " .. remote.url
    end,
    render_result = function(_, result_bufnr, itemmap, matches)
      local lines = {} ---@type string[]
      local uuids = {} ---@type string[]

      for _, match in ipairs(matches) do
        local item = itemmap[match.uuid] ---@type ux.picker.composer.list.IItem
        lines[#lines + 1] = item.text
        uuids[#uuids + 1] = item.uuid
      end

      vim.api.nvim_buf_set_lines(result_bufnr, 0, -1, false, lines)

      local nsnr_content = dot.var.nsnr.picker_result ---@type integer
      local nsnr_matches = dot.var.nsnr.picker_matches ---@type integer

      for lnum, match in ipairs(matches) do
        local row = lnum - 1 ---@type integer
        local item = itemmap[match.uuid] ---@type ux.picker.composer.list.IItem

        if item and item.highlights then
          for _, hl in ipairs(item.highlights) do
            vim.hl.range(result_bufnr, nsnr_content, hl.hlname, { row, hl.coll }, { row, hl.colr }, { priority = 10 })
          end
        end

        local separator_pos = max_name_width + 1 ---@type integer
        vim.hl.range(result_bufnr, nsnr_content, "DiagnosticInfo", { row, 0 }, { row, max_name_width }, { priority = 15 })
        vim.hl.range(result_bufnr, nsnr_content, "Comment", { row, separator_pos }, { row, separator_pos + 3 }, { priority = 15 })
        vim.hl.range(result_bufnr, nsnr_content, "DiagnosticHint", { row, separator_pos + 3 }, { row, #item.text }, { priority = 15 })

        if match.matches then
          for _, m in ipairs(match.matches) do
            vim.hl.range(result_bufnr, nsnr_matches, "f_pk_matches", { row, m.l }, { row, m.r }, { priority = 30 })
          end
        end
      end

      ---@type ux.picker.composer.list.IRenderResultData
      local data = { uuids = uuids }
      return data
    end,
  }, function(choice)
    if choice then
      open_remote(choice)
    end
  end)
end

return M
