require("eve.option")
require("eve.autocmd")
require("eve.autocmd_filetype")
require("eve.keymap")
_G.eve = require("eve")
do
  local is_git_repo = eve.path.is_git_repo() ---@type boolean

  ---@type eve.t.context.storage
  local storage = {
    editor = eve.path.locate_context_filepath("editor.json"),
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

require("ghc.dressing.autopairs")
require("ghc.dressing.commentstring")
require("ghc.dressing.select")
require("ghc.dressing.winsep")
require("ghc.command")

eve.commander.execute(eve.commander.uuids.reload_theme)
vim.schedule(function()
  eve.commander.execute(eve.commander.uuids.reload_theme)
  eve.context.watch_changes({
    on_theme_changed = function()
      eve.commander.execute(eve.commander.uuids.reload_theme)
    end,
  })
end)

require("guanghechen.option")
if vim.g.neovide then
  require("integration.neovide.option")
  require("integration.neovide.autocmd")
  require("integration.neovide.keymap")
end

require("guanghechen.plugin")
require("guanghechen.command")
if vim.g.neovide then
  require("integration.neovide.plugin")
end
pcall(require, "integration.local")

---! Reload session if not specify file and current directory is a git repository.
if eve.path.is_git_repo() and eve.context.state.flight.autoload:snapshot() then
  eve.nvim.load_nvim_session(eve.context.storage.nvim_session_autosaved)
end
