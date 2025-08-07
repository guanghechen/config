require("eve.option")
require("eve.keymap")
require("eve.autocmd")
require("integration.neovim.autocmd")
pcall(require, "integration.local.autocmd")

eve.setup_context()
require("integration.neovide.option")
require("integration.neovide.keymap")
pcall(require, "integration.local.option")
pcall(require, "integration.local.keymap")

require("fml.dressing.notifier")
require("fml.dressing.ui_attach")
require("fml.dressing.nvimbar.statusline")
require("fml.dressing.nvimbar.tabline")
require("fml.dressing.nvimbar.winline")
eve.setup_theme()

require("fml.command")
require("ghc.plugin")
pcall(require, "integration.neovide.plugin")
pcall(require, "integration.local.plugin")
require("ghc.command")

---! Reload session if not specify file and current directory is a git repository.
if std.path.is_git_repo() then
  if eve.context.flight.autoload:snapshot() then
    eve.session.load_session(eve.context.get_storage().nvim_session_autosaved)
    vim.schedule(eve.tab.refresh)
  end
end

vim.schedule(function()
  require("fml.dressing.clipboard")
  require("fml.dressing.commentstring")
  require("fml.dressing.foldexpr")
  require("fml.dressing.hipairs")
  require("fml.dressing.illumniate")
  require("fml.dressing.im")
  require("fml.dressing.image")
  require("fml.dressing.indentline")
  require("fml.dressing.input")
  require("fml.dressing.python_venv")
  require("fml.dressing.select")
  require("fml.dressing.statuscolumn")
  require("fml.dressing.winsep")
  pcall(require, "integration.neovide.dressing")
  pcall(require, "integration.local.dressing")

  eve.setup_breakpoints()
  eve.setup_lsp()
end)
