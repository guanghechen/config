---@diagnostic disable-next-line: unused-local
local __module_name__ = "bot" ---@type string

---@class bot
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

---@return nil
function M.setup_clipboard()
  local function tmux_clipboard()
    return {
      name = "OSC 52",
      copy = {
        ["+"] = require("vim.ui.clipboard.osc52").copy("+"),
        ["*"] = require("vim.ui.clipboard.osc52").copy("*"),
      },
      paste = {
        ["+"] = require("vim.ui.clipboard.osc52").paste("+"),
        ["*"] = require("vim.ui.clipboard.osc52").paste("*"),
      },
    }
  end

  local function wsl_clipboard()
    return {
      name = "WslClipboard",
      copy = {
        ["+"] = "clip.exe",
        ["*"] = "clip.exe",
      },
      paste = {
        ["+"] = 'pwsh.exe -c [Console]::Out.Write($(Get-Clipboard -Raw).tostring().replace("`r", ""))',
        ["*"] = 'pwsh.exe -c [Console]::Out.Write($(Get-Clipboard -Raw).tostring().replace("`r", ""))',
      },
      cache_enabled = 0,
    }
  end

  if stl.env.IS_OSX then
    if stl.env.IS_TMUX then
      vim.g.clipboard = tmux_clipboard()
    end
    return
  end

  if stl.env.IS_WSL then
    vim.g.clipboard = wsl_clipboard()
  end
end

---@return nil
function M.setup_shell()
  if stl.env.IS_OSX then
    -- vim.o.shell = "/bin/bash"
  elseif stl.env.IS_NIX then
    -- vim.o.shell = "/usr/bin/bash"
    -- vim.o.shell = "/home/linuxbrew/.linuxbrew/bin/fish"
  elseif stl.env.IS_WSL then
    -- vim.o.shell = "/usr/bin/bash"
    -- vim.o.shell = "/home/linuxbrew/.linuxbrew/bin/fish"
    ---@diagnostic disable-next-line: unused-local, duplicate-set-field
    vim.ui.open = function(path, opt)
      vim.fn.jobstart({ "fish", "-c", "open " .. vim.fn.shellescape(path) }, { detach = true })
      return nil, function() end
    end
  elseif stl.env.IS_WIN then
    vim.o.shell = "pwsh"

    -- Setting shell command flags
    vim.o.shellcmdflag =
      "-NoLogo -NonInteractive -ExecutionPolicy RemoteSigned -Command [Console]::InputEncoding=[Console]::OutputEncoding=[System.Text.UTF8Encoding]::new();$PSDefaultParameterValues['Out-File:Encoding']='utf8';$PSStyle.OutputRendering='plaintext';Remove-Alias -Force -ErrorAction SilentlyContinue tee;"

    -- Setting shell redirection
    vim.o.shellredir = '2>&1 | %%{ "$_" } | Out-File %s; exit $LastExitCode'

    -- Setting shell pipe
    vim.o.shellpipe = '2>&1 | %%{ "$_" } | tee %s; exit $LastExitCode'

    -- Setting shell quote options
    vim.o.shellquote = ""
    vim.o.shellxquote = ""
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

    local A = stl.env.locate_gitroot(p)

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
    else
      local B = stl.env.locate_gitroot(cwd)
      if A ~= B then
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
  end

  yoz.path.set_cwd(vim.fn.getcwd())

  ---! Clear jumplist. See https://superuser.com/questions/1642954/how-to-start-vim-with-a-clean-jumplist
  vim.schedule(function()
    vim.cmd("clearjumps")
  end)
end

---@return nil
function M.setup()
  _G.yoz = require("yoz") ---@type yoz
  _G.stl = require("stl") ---@type stl

  -- Mark initial tab as normal
  local tabnr = vim.api.nvim_get_current_tabpage() ---@type integer
  vim.t[tabnr].tabtype = stl.e.TabTypeEnum.NORMAL

  M.setup_patches()
  M.setup_shell()
  M.setup_workspace()

  require("ark.option")
  require("ark.keymap")
  require("ark.autocmd")

  _G.dot = require("dot") ---@type dot
  _G.era = require("era") ---@type era
end

return M
