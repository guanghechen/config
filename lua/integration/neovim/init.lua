require("era.autocmd")
require("integration.neovim.autocmd")
pcall(require, "integration.local.autocmd")

era.setup_context()
require("integration.neovim.option")
require("integration.neovim.keymap")
pcall(require, "integration.local.option")
pcall(require, "integration.local.keymap")

require("fml.dressing.notifier")
require("fml.dressing.ui_attach")

require("fml.command")
require("ghc.plugin")
pcall(require, "integration.local.plugin")
require("ghc.command")

---! Reload session if not specify file and current directory is a git repository.
if era.path.is_git_repo() then
  if era.context.flight.autoload:snapshot() then
    era.session.load_session(era.context.get_storage().nvim_session_autosaved)
    vim.schedule(era.tab.refresh)
  end
end

vim.schedule(function()
  require("fml.dressing.nvimbar.statusline")
  require("fml.dressing.nvimbar.tabline")
  require("fml.dressing.nvimbar.winline")
  require("fml.dressing.commentstring")
  require("fml.dressing.foldtext")
  require("fml.dressing.scroll")
  require("fml.dressing.statuscolumn")
  require("fml.dressing.virtcolumn")
  require("fml.dressing.winsep")

  require("fml.dressing.clipboard")
  require("fml.dressing.dim")
  require("fml.dressing.illumniate")
  require("fml.dressing.im")
  require("fml.dressing.input")
  require("fml.dressing.lsp_action")
  require("fml.dressing.python_venv")
  require("fml.dressing.select")
  require("fml.dressing.trailspace")
  require("fml.dressing.image")
  pcall(require, "integration.local.dressing")

  era.setup_breakpoints()
  era.setup_diagnostics()
  era.setup_lsp()
  era.context.watch_changes()
end)
