require("eve.setup").workspace()
require("eve.setup").context()
require("eve.setup").clear_jumplist()

require("eve.option")
require("eve.autocmd")
require("eve.autocmd_filetype")
require("eve.keymap")
_G.eve = require("eve")

require("fml.autocmd")
_G.fml = require("fml")

if vim.g.vscode then
  require("integration.vscode.autocmd")
  require("integration.vscode.option")
  require("integration.vscode.keymap")
  require("integration.vscode.plugin")
  pcall(require, "integration.local")
  return
end

require("ghc.command")
require("ghc.dressing.autopairs")
require("ghc.dressing.commentstring")
require("ghc.dressing.nvimbar.statusline")
require("ghc.dressing.nvimbar.tabline")
require("ghc.dressing.nvimbar.winline")
require("ghc.dressing.select")
require("ghc.dressing.winsep")

eve.commander.execute(eve.commander.uuids.reload_theme)
vim.schedule(function()
  eve.commander.execute(eve.commander.uuids.reload_theme)
  eve.state.watch_changes({
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
local path = require("eve.lib.path")
if path.is_git_repo() and eve.state.state.flight.autoload:snapshot() then
  eve.nvim.load_nvim_session(eve.state.get_storage().nvim_session_autosaved)
end
