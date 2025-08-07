local __module_name__ = "std.bootstrap" ---@type string

local os_name = vim.uv.os_uname().sysname ---@type string|nil
local IS_WIN = os_name == "Windows_NT" ---@type boolean
local PATH_SEP = IS_WIN and "\\" or "/" ---@type string
local BYTE_COLON = 0x3a --[[ ':'  ]]
local BYTE_PATHSEP = string.byte(PATH_SEP) ---@type integer

---@param filepath                      string
---@return string[]
local function split_path(filepath)
  local L = #filepath ---@type integer
  local pieces = {} ---@type string[]
  local pattern = "([^/\\]+)" ---@type string
  local has_prefix_sep = PATH_SEP == "/" and string.byte(filepath, 1, 1) == BYTE_PATHSEP ---@type boolean

  local k = 0 ---@type integer
  if has_prefix_sep then
    k = k + 1 ---@type integer
    pieces[k] = ""
  end

  for piece in string.gmatch(filepath, pattern) do
    if piece ~= "" and piece ~= "." then
      if piece == ".." and (has_prefix_sep or k > 0) then
        pieces[k] = nil
        k = k - 1 ---@type integer
      else
        k = k + 1 ---@type integer
        pieces[k] = piece
      end
    end
  end

  if IS_WIN and L > 1 and string.byte(filepath, 2, 2) == BYTE_COLON then
    pieces[1] = pieces[1]:upper()
  end
  return pieces
end

---@param dirpath                       string
---@return string|nil
local function locate_gitroot_by_cmd(dirpath)
  local ok, p = pcall(vim.fn.system, { "git", "-C", dirpath, "rev-parse", "--show-toplevel" }) ---@type boolean, string
  if not ok then
    return nil
  end

  if p:sub(1, 5) ~= "fatal" then
    return vim.trim(p)
  end

  return nil
end

---@param dirpath                       string
---@return string|nil
local function locate_gitroot(dirpath)
  if vim.uv.fs_stat(dirpath .. PATH_SEP .. ".git") ~= nil then
    return dirpath
  end

  local pieces = split_path(dirpath) ---@type string[]
  for index = #pieces - 1, 1, -1 do
    local p = table.concat(pieces, PATH_SEP, 1, index) ---@type string
    if vim.uv.fs_stat(p .. PATH_SEP .. ".git") ~= nil then
      return p
    end
  end

  return locate_gitroot_by_cmd(dirpath)
end

---@class std.bootstrap
local M = {}

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
  if vim.fn.expand("%") ~= "" then
    local cwd = vim.uv.cwd() or vim.fn.getcwd() ---@type string
    local p = vim.fn.expand("%:p:h")
    local A = locate_gitroot(p)
    local B = locate_gitroot(cwd)

    if A == nil then
      local ok, err = pcall(function()
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
