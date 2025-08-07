local __module_name__ = "std.bootstrap" ---@type string

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
  local INITIAL_FILEPATH = vim.fn.expand("%") ---@type string
  if INITIAL_FILEPATH ~= "" then
    local cwd = vim.uv.cwd() or vim.fn.getcwd() ---@type string
    local p = vim.fn.expand("%:p:h")

    local env = require("std.env")
    local A = env.locate_gitroot(p)
    local B = env.locate_gitroot(cwd)

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
