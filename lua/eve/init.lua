---@class eve
local M = {
  G = require("eve.builtin.G"),
  debug = require("eve.builtin.debug"),
  env = require("eve.builtin.env"),
  fn = require("eve.builtin.fn"),
}

---@return eve.state.storage
function M.get_default_storage()
  local path = require("eve.builtin.path")
  local is_git_repo = path.is_git_repo() ---@type boolean

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
  local path = require("eve.builtin.path")
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
