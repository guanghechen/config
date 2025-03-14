---@class eve.__mods
local __mods = {
  debug = "eve.builtin.debug",
  env = "eve.builtin.env",
  path = "eve.builtin.path",
}

local __gid = 0 ---@type integer
local __gfn = {} ---@type table<string, fun(...): nil>

---@class eve
---@field public __mods                 eve.__mods
---@field public debug                  eve.builtin.debug
---@field public env                    eve.builtin.env
---@field public path                   eve.builtin.path
---
---@field public G                      eve.G
---@field public c                      eve.collection
---@field public lib                    eve.lib
---@field public std                    eve.std
---
---@field public debug                  eve.debug
local M = setmetatable({
  ---@class eve.G
  G = setmetatable({
    ---@param fn                       fun(...): nil
    ---@return string
    register_anonymous_fn = function(fn)
      __gid = __gid + 1
      local fn_name = "_" .. __gid
      __gfn[fn_name] = fn
      return "eve.G." .. fn_name
    end,
  }, { __index = __gfn }),
  c = require("eve.constant"),
  col = require("eve.collection"),
  lib = require("eve.lib"),
  std = require("eve.std"),
}, {
  __index = function(t, k)
    local m = __mods[k] ---@type string|nil
    if m == nil then
      return rawget(t, k)
    end
    return require(m)
  end,
})

---@return eve.state.storage
function M.get_default_storage()
  local path = require("eve.path")
  local is_git_repo = path.is_repo_git() ---@type boolean

  ---@type eve.state.storage
  return {
    editor = path.locate_context_filepath("editor.json"),
    session = is_git_repo and path.locate_workspace_filepath("session.json") or nil,
    workspace = is_git_repo and path.locate_workspace_filepath("workspace.json") or nil,
    nvim_session = is_git_repo and path.locate_workspace_filepath("session.vim") or nil,
    nvim_session_autosaved = is_git_repo and path.locate_workspace_filepath("session.autosaved.vim") or nil,
  }
end

---@return nil
function M.setup_breakpoints()
  local state = require("eve.state")
  local breakpoints = state.lsp.breakpoints:snapshot() ---@type eve.state.lsp.IBreakpointData
  if #breakpoints < 1 then
    return
  end

  local filepath_set = {} ---@type table<string, true>
  for _, breakpoint in ipairs(breakpoints) do
    filepath_set[breakpoint.filepath] = true
  end
  local filepaths = vim.tbl_keys(filepath_set) ---@type string[]

  local editor = require("eve.module.editor")
  editor.open_filepaths(0, filepaths)

  vim.defer_fn(function()
    local bps = require("dap.breakpoints")
    for _, breakpoint in ipairs(breakpoints) do
      local bufnr = state.buf.locate_by_filepath(breakpoint.filepath) ---@type integer|nil
      if bufnr ~= nil then
        bps.set({
          condition = breakpoint.condition,
          hit_condition = breakpoint.hit_condition,
          log_message = breakpoint.log_message,
        }, bufnr, breakpoint.lnum)
      end
    end
  end, 100)
end

---@return nil
function M.setup_patches()
  vim.hl = vim.hl or vim.highlight --- vim.hl has been renamed to vim.highlight
  table.unpack = table.unpack or unpack --- table.unpack is introduced in Lua 5.2
end

---! Auto cd the directory:
---! 1. the opened file is under a git repo, let's remember the the git repo path as A,
---!    and assume the git repo directory of the shell cwd is B.
---!      a) If A is different from B, then auto cd the A.
---!      b) If A is the same as B, then no action needed.
---! 2. the opened file is not under a git repo, then auto cd the directory of the opened file.
---@return nil
function M.setup_workspace()
  local path = require("eve.path")
  if vim.fn.expand("%") ~= "" then
    local cwd = vim.uv.cwd() or vim.fn.getcwd() ---@type string
    local p = vim.fn.expand("%:p:h")
    local A = path.locate_git_repo(p)
    local B = path.locate_git_repo(cwd)

    if A == nil then
      pcall(function()
        vim.api.nvim_set_current_dir(p)
      end)
    elseif A ~= B then
      vim.api.nvim_set_current_dir(A)
    end
  end

  ---! Clear jumplist. See https://superuser.com/questions/1642954/how-to-start-vim-with-a-clean-jumplist
  vim.schedule(function()
    vim.cmd("clearjumps")
  end)
end

---@param storage                       eve.state.storage|nil
---@return nil
function M.setup_state(storage)
  storage = storage or M.get_default_storage() ---@type eve.state.storage

  local state = require("eve.state")
  state.set_storage(storage)
  state.load(storage, true)
end

---@return nil
function M.setup_theme()
  local state = require("eve.state")

  state.theme.reload_theme(false, false)
  vim.schedule(function()
    state.watch_changes({
      on_theme_changed = function()
        state.theme.reload_theme(false, true)
      end,
    })
  end)

  ---Trigger reload the cover the unexpected changes by the plugins
  vim.defer_fn(function()
    state.theme.reload_theme(false, false)
  end, 100)
end

return M
