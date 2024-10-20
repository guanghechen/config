require("eve.autocmd")
local eve = require("eve")
_G.eve = eve

do
  local is_git_repo = eve.path.is_git_repo() ---@type boolean

  ---@type t.eve.context.storage
  local storage = {
    client = eve.path.locate_context_filepath("client.json"),
    session = is_git_repo and eve.path.locate_session_filepath("session.json") or nil,
    workspace = is_git_repo and eve.path.locate_session_filepath("workspace.json") or nil,
    nvim_session = is_git_repo and eve.path.locate_session_filepath("session.vim") or nil,
    nvim_session_autosaved = is_git_repo and eve.path.locate_session_filepath("session.autosaved.vim") or nil,
  }
  eve.context.set_storage(storage)
  eve.context.load(storage)
end

require("fml.autocmd")
_G.fml = require("fml")

require("ghc.autocmd")
_G.ghc = require("ghc")

if vim.g.vscode then
  require("integration.vscode.autocmd")
  require("integration.vscode.option")
  require("integration.vscode.keymap")
  require("integration.vscode.plugin")
  pcall(require, "integration.local")
  return
end

require("ghc.dressing.select")
if vim.g.neovide then
  require("integration.neovide.autocmd")
  require("integration.neovide.keymap")
  require("integration.neovide.option")
  require("integration.neovide.plugin")
  pcall(require, "integration.local")
else
  require("guanghechen.option")
  require("guanghechen.keymap")
  require("guanghechen.plugin")
  pcall(require, "integration.local")
end

---! Reload session if not specify file and current directory is a git repository.
if eve.path.is_git_repo() and eve.context.state.flight.autoload:snapshot() then
  eve.nvim.load_nvim_session(eve.context.storage.nvim_session_autosaved)
end

vim.schedule(function()
  ghc.action.theme.reload_theme({ force = false })
  eve.context.watch_changes({
    on_theme_changed = function()
      ghc.action.theme.reload_theme({ force = false })
    end,
  })
end)
