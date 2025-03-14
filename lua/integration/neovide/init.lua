_G.eve = require("eve")
eve.setup_patches()
eve.setup_workspace()
require("eve.option")
require("eve.keymap")
require("integration.neovim.autocmd")
pcall(require, "integration.local.autocmd")

eve.setup_state()
require("eve.state.autocmd")

---! Reload session if not specify file and current directory is a git repository.
if eve.std.path.is_repo_git() then
  local state = require("eve.state")
  if state.flight.autoload:snapshot() then
    local session = require("eve.module.session")
    session.load_session(state.get_storage().nvim_session_autosaved)
  end
end

require("integration.neovide.option")
require("integration.neovide.keymap")
pcall(require, "integration.local.option")
pcall(require, "integration.local.keymap")

eve.setup_theme()
require("fml.dressing.nvimbar.statusline")
require("fml.dressing.nvimbar.tabline")
require("fml.dressing.nvimbar.winline")

vim.schedule(function()
  require("ghc.plugin")
  pcall(require, "integration.local.plugin")

  vim.schedule(function()
    require("fml.command")
    require("ghc.command")
    eve.setup_breakpoints()
  end)

  vim.schedule(function()
    require("fml.dressing.commentstring")
    require("fml.dressing.hipairs")
    require("fml.dressing.illumniate")
    if eve.env.IS_MAC or eve.env.IS_NIX or eve.env.IS_WSL then
      require("fml.dressing.image")
    end
    require("fml.dressing.input")
    require("fml.dressing.python_venv")
    require("fml.dressing.select")
    require("fml.dressing.winsep")
    pcall(require, "integration.local")
  end)
end)