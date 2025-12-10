local __module_name__ = "bootstrap" ---@type string

---@param dirpath                       string
---@return string|nil
function vim.fn.locate_gitroot(dirpath)
  local git_path = yoz.path.locate_nearest(dirpath, { ".git" }) ---@type string|nil
  if git_path ~= nil then
    local SEP = package.config:sub(1, 1) ---@type string
    return yoz.path.dirname(git_path, false, SEP)
  end

  local ok, output = pcall(vim.fn.system, { "git", "-C", dirpath, "rev-parse", "--show-toplevel" }) ---@type boolean, string
  local trimmed_output = vim.trim(output or "")
  local shell_error = vim.v.shell_error ---@type integer

  if ok and shell_error == 0 and trimmed_output ~= "" and yoz.path.is_exist_dirpath(trimmed_output) then
    return trimmed_output
  end

  local message = "Failed to locate git root"
  local detail_payload = {
    dirpath = dirpath,
    output = trimmed_output,
    shell_error = shell_error,
    error = ok and nil or output,
  }
  local ok_json, detail_json = pcall(vim.json.encode, detail_payload)
  local details_text = ok_json and detail_json or vim.inspect(detail_payload, { newline = "\n", indent = "  " })
  local text = string.format("%s\n\n```json\n%s\n```", message, details_text)

  vim.notify(text, vim.log.levels.WARN, {
    title = string.format("%s │ locate_gitroot", __module_name__),
    group = string.format("%s:locate_gitroot", __module_name__),
    timeout = 3000,
    message = text,
    anonymous = false,
    silent = true,
  })
  return nil
end

---@class bootstrap
local M = {}

---@return nil
function M.setup()
  _G.yoz = require("yoz") ---@type yoz
  M.setup_patches()
  M.setup_workspace()
end

---@return nil
function M.setup_patches()
  table.unpack = table.unpack or unpack --- table.unpack is introduced in Lua 5.2
  table.clear = table.clear or function(map)
    for k in pairs(map) do
      map[k] = nil
    end
  end
end

---! Auto cd the directory:
---! 1. the opened file is under a git repo, let's remember the the git repo path as A,
---!    and assume the git repo directory of the shell cwd is B.
---!      a) If A is different from B, then auto cd the A.
---!      b) If A is the same as B, then no action needed.
---! 2. the opened file is not under a git repo, then auto cd the directory of the opened file.
---@return nil
function M.setup_workspace()
  local INITIAL_FILEPATH = vim.fn.expand("%") ---@type string
  if INITIAL_FILEPATH ~= "" then
    local cwd = vim.uv.cwd() or vim.fn.getcwd() ---@type string
    local p = vim.fn.expand("%:p:h")

    local A = vim.fn.locate_gitroot(p)
    local B = vim.fn.locate_gitroot(cwd)

    if A == nil then
      local ok, err = pcall(function()
        yoz.path.set_cwd(p)
        vim.api.nvim_set_current_dir(p)
      end)
      if not ok then
        local message = "Failed to change directory to file directory" ---@type string
        local details = { path = p, error = err } ---@type table
        message = message .. "\n\n" .. "```json\n" .. vim.inspect(details, { newline = "\n" }) .. "\n```" ---@type string

        vim.schedule(function()
          vim.notify(message, vim.log.levels.WARN, {
            group = nil,
            title = string.format("%s | %s", __module_name__, "setup_workspace"),
            timeout = 3000,
            message = message,
            anonymous = false,
            silent = false,
          })
        end)
      end
    elseif A ~= B then
      local ok, err = pcall(function()
        vim.api.nvim_set_current_dir(A)
      end)
      if not ok then
        local message = "Failed to change directory to git repo" ---@type string
        local details = { repopath = A, error = err } ---@type table
        message = message .. "\n\n" .. "```json\n" .. vim.inspect(details, { newline = "\n" }) .. "\n```" ---@type string

        vim.schedule(function()
          vim.notify(message, vim.log.levels.WARN, {
            group = nil,
            title = string.format("%s | %s", __module_name__, "setup_workspace"),
            timeout = 3000,
            message = message,
            anonymous = false,
            silent = false,
          })
        end)
      end
    end
  end

  ---! Clear jumplist. See https://superuser.com/questions/1642954/how-to-start-vim-with-a-clean-jumplist
  vim.schedule(function()
    vim.cmd("clearjumps")
  end)
end

return M
