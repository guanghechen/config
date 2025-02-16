_G.eve = require("eve")
eve.setup_patches()
eve.setup_workspace()
require("eve.option")
require("eve.autocmd")
require("eve.autocmd-filetype")

eve.setup_state()
require("eve.autocmd-state")
require("eve.keymap")

eve.setup_theme()

require("fml.command")
require("fml.dressing.hipairs")
require("fml.dressing.commentstring")
require("fml.dressing.illumniate")
if eve.env.IS_MAC then
  require("fml.dressing.image")
end
require("fml.dressing.input")
require("fml.dressing.nvimbar.statusline")
require("fml.dressing.nvimbar.tabline")
require("fml.dressing.nvimbar.winline")
require("fml.dressing.select")
require("fml.dressing.winsep")

require("ghc.option")
require("ghc.command")
require("integration.neovide.option")
require("integration.neovide.autocmd")
require("integration.neovide.keymap")

require("ghc.plugin")
require("integration.neovide.plugin")
pcall(require, "integration.local")

---! Reload session if not specify file and current directory is a git repository.
local path = require("eve.builtin.path")
if path.is_git_repo() then
  local state = require("eve.state")
  if state.flight.autoload:snapshot() then
    local session = require("eve.module.session")
    session.load_session(state.get_storage().nvim_session_autosaved)
  end
end
