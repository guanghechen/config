local env = require("eve.lib.env")
local path = require("eve.lib.path")

---@class eve.setup
local M = {}

---! Auto cd the directory:
---! 1. the opend file is under a git repo, let's remember the the git repo path as A,
---!    and assume the git repo directory of the shell cwd is B.
---!      a) If A is different from B, then auto cd the A.
---!      b) If A is the same as B, then no action needed.
---! 2. the opened file is not under a git repo, then auto cd the directory of the opened file.
---@return nil
function M.workspace()
  if vim.fn.expand("%") ~= "" then
    local cwd = vim.fn.getcwd()
    local p = vim.fn.expand("%:p:h")
    local A = path.locate_git_repo(p)
    local B = path.locate_git_repo(cwd)

    if A == nil then
      vim.cmd("cd " .. p .. "")
    elseif A ~= B then
      vim.cmd("cd " .. A .. "")
    end
  end
end

---@return nil
function M.context()
  local state = require("eve.state")
  local is_git_repo = path.is_git_repo() ---@type boolean

  ---@type eve.t.state.storage
  local storage = {
    editor = path.locate_context_filepath("editor.json"),
    session = is_git_repo and path.locate_session_filepath("session.json") or nil,
    workspace = is_git_repo and path.locate_session_filepath("workspace.json") or nil,
    nvim_session = is_git_repo and path.locate_session_filepath("session.vim") or nil,
    nvim_session_autosaved = is_git_repo and path.locate_session_filepath("session.autosaved.vim") or nil,
  }
  state.set_storage(storage)
  state.load(storage)
end

---! Setup the input method auto toggling
function M.auto_toggle_im()
  if env.IS_MAC then
    local im = require("eve.lib.im")
    local previous_mode = nil ---@type eve.e.VimMode|nil
    vim.api.nvim_create_autocmd({ "ModeChanged" }, {
      callback = function()
        local current_mode = vim.fn.mode() ---@type eve.e.VimMode|nil
        if previous_mode == "i" and current_mode == "n" then
          im.set_input_method("English")
        end
        previous_mode = current_mode
      end,
    })
  end
end

---! Clear jumplist. See https://superuser.com/questions/1642954/how-to-start-vim-with-a-clean-jumplist
---@return nil
function M.clear_jumplist()
  vim.schedule(function()
    vim.cmd("clearjumps")
  end)
end

return M
