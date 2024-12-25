_G.eve = require("eve")

eve.setup_workspace()
require("eve.option")
require("eve.keymap")
require("eve.autocmd")
require("eve.autocmd-filetype")

eve.setup_state()
require("eve.autocmd-state")

if vim.g.vscode then
  require("integration.vscode.autocmd")
  require("integration.vscode.option")
  require("integration.vscode.keymap")
  require("integration.vscode.plugin")
  pcall(require, "integration.local")
  return
end

require("fml.command")
require("fml.dressing.hipairs")
require("fml.dressing.commentstring")
require("fml.dressing.nvimbar.statusline")
require("fml.dressing.nvimbar.tabline")
require("fml.dressing.nvimbar.winline")
require("fml.dressing.select")
require("fml.dressing.winsep")

local state = require("eve.state")
local command = require("eve.lib.command")
vim.cmd(command.definitions.ux.reload_theme.uuid)
vim.schedule(function()
  vim.cmd(command.definitions.ux.reload_theme.uuid)
  state.watch_changes({
    on_theme_changed = function()
      vim.cmd(command.definitions.ux.reload_theme.uuid)
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
if path.is_git_repo() and state.flight.autoload:snapshot() then
  require("eve.lib.nvim").load_nvim_session(state.get_storage().nvim_session_autosaved)
end
