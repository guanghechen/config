local __module_name__ = "fml.action.git.browse" ---@type string

---@alias fml.action.git.browse.TargetScope
---| "branch"
---| "file"
---| "repo"

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
    std.reporter.error({
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
    std.reporter.error({
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
  local command = std.env.IS_WIN
  and 'git rev-parse --abbrev-ref HEAD 2>$null'
  or 'git rev-parse --abbrev-ref HEAD 2>/dev/null'

  -- Run the git command to get the branch name
  local handle = io.popen(command)
  if not handle then
    std.reporter.error({
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
    command = std.env.IS_WIN
    and 'git rev-parse HEAD 2>$null'
    or 'git rev-parse HEAD 2>/dev/null'

    handle = io.popen(command)
    if not handle then
      std.reporter.error({
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

---@return string|nil, integer, integer
local function get_file_line()
  local mode = vim.fn.mode()
  local line_start, line_end ---@type integer, integer

  if mode == "v" or mode == "V" or mode == "\22" then
    line_start = vim.fn.line("v")
    line_end = vim.fn.line(".")

    if line_start > line_end then
      line_start, line_end = line_end, line_start
    end
  else
    local current_line = vim.fn.line(".")
    line_start = current_line
    line_end = current_line
  end

  return line_start .. "-L" .. line_end, line_start, line_end
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
    std.reporter.info({
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
  local tabnr = vim.api.nvim_get_current_tabpage() ---@type integer
  local bufnr_sourcefile = eve.tab.retrieve_bufnr_sourcefile(tabnr) ---@type integer|nil
  if bufnr_sourcefile == nil then
    return
  end

  local workspace = std.path.workspace() ---@type string
  local filepath = vim.api.nvim_buf_get_name(bufnr_sourcefile) ---@type string|nil
  filepath = filepath ~= nil and std.path.is_under(workspace, filepath) and std.path.relative(workspace, filepath, true) or nil

  local remotes = {} ---@type fml.action.git.browse.IRemote[]
  local line_fragment, line_start, line_end ---@type string|nil, integer|nil, integer|nil
  if filepath then
    line_fragment, line_start, line_end = get_file_line()
  end

  local fields = {
    branch = get_git_branch_or_commit(),
    file = filepath,
    line = line_fragment,
    line_start = line_start,
    line_end = line_end,
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
            return fields[string.sub(key, 2, -2)] or key
          end),
        }
        table.insert(remotes, remote)
      end
    end
  end

  if #remotes == 0 then
    std.reporter.error({
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
    result_render = function(_, bufnr, itemmap, matches)
      local lines = {} ---@type string[]
      local uuids = {} ---@type string[]

      for _, match in ipairs(matches) do
        local item = itemmap[match.uuid] ---@type eve.ux.picker.composer.list.IItem
        lines[#lines + 1] = item.text
        uuids[#uuids + 1] = item.uuid
      end

      vim.api.nvim_buf_set_lines(bufnr, 0, -1, false, lines)

      local nsnr_content = eve.var.nsnr.picker_result ---@type integer
      local nsnr_matches = eve.var.nsnr.picker_matches ---@type integer

      for lnum, match in ipairs(matches) do
        local row = lnum - 1 ---@type integer
        local item = itemmap[match.uuid] ---@type eve.ux.picker.composer.list.IItem

        if item and item.highlights then
          for _, hl in ipairs(item.highlights) do
            vim.hl.range(bufnr, nsnr_content, hl.hlname, { row, hl.coll }, { row, hl.colr }, { priority = 10 })
          end
        end

        local separator_pos = max_name_width + 1 ---@type integer
        vim.hl.range(bufnr, nsnr_content, "DiagnosticInfo", { row, 0 }, { row, max_name_width }, { priority = 15 })
        vim.hl.range(bufnr, nsnr_content, "Comment", { row, separator_pos }, { row, separator_pos + 3 }, { priority = 15 })
        vim.hl.range(bufnr, nsnr_content, "DiagnosticHint", { row, separator_pos + 3 }, { row, #item.text }, { priority = 15 })

        if match.matches then
          for _, m in ipairs(match.matches) do
            vim.hl.range(bufnr, nsnr_matches, "f_pk_matches", { row, m.l }, { row, m.r }, { priority = 30 })
          end
        end
      end

      ---@type eve.ux.picker.composer.list.IResultRenderData
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

