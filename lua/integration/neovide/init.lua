_G.eve = require("eve")
eve.setup_patches()
eve.setup_workspace()
require("eve.option")
require("eve.keymap")
require("integration.neovim.autocmd")

eve.setup_state()
require("eve.autocmd-state")

require("integration.neovide.option")
require("integration.neovide.keymap")

eve.setup_theme()

if eve.std.env.IS_MAC then
  require("fml.dressing.image")
end
require("fml.command")
require("fml.dressing.hipairs")
require("fml.dressing.commentstring")
require("fml.dressing.illumniate")
require("fml.dressing.input")
require("fml.dressing.nvimbar.statusline")
require("fml.dressing.nvimbar.tabline")
require("fml.dressing.nvimbar.winline")
require("fml.dressing.python_venv")
require("fml.dressing.select")
require("fml.dressing.winsep")

require("ghc.command")
require("ghc.plugin")
pcall(require, "integration.local")

---! Reload session if not specify file and current directory is a git repository.
if eve.std.path.is_repo_git() then
  local state = require("eve.state")
  if state.flight.autoload:snapshot() then
    local session = require("eve.module.session")
    session.load_session(state.get_storage().nvim_session_autosaved)
  end
end

vim.schedule(function()
  eve.setup_breakpoints()
end)
