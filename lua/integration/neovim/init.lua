require("dot.autocmd")
pcall(require, "integration.local.autocmd")

dot.setup_context()
require("integration.neovim.option")
require("integration.neovim.keymap")
pcall(require, "integration.local.option")
pcall(require, "integration.local.keymap")

require("era.dressing.notifier")
require("era.dressing.ui_attach")
require("era.command")

if dot.path.is_git_repo() then
  require("dot.module.git")
end

require("era.plugin")
pcall(require, "integration.local.plugin")

---! Reload session if not specify file and current directory is a git repository.
if dot.path.is_git_repo() then
  if dot.context.flight.autoload:snapshot() then
    dot.session.load_session(dot.context.get_storage().nvim_session_autosaved)
    vim.schedule(dot.tab.refresh)
  end
end

vim.schedule(function()
  require("era.dressing.statusline")
  require("era.dressing.tabline")
  require("era.dressing.winline")

  require("era.dressing.commentstring")
  require("era.dressing.foldtext")
  require("era.dressing.scroll")
  require("era.dressing.statuscolumn")
  require("era.dressing.trailspace")
  require("era.dressing.virtcolumn")
  require("era.dressing.winsep")

  require("era.dressing.dim")
  require("era.dressing.im")
  require("era.dressing.input")
  require("era.dressing.lsp")
  require("era.dressing.lsp_action")
  require("era.dressing.python_venv")
  require("era.dressing.select")
  require("era.dressing.image")
  pcall(require, "integration.local.dressing")

  dot.setup_breakpoints()
  dot.setup_diagnostics()
  dot.setup_lsp()
  dot.context.watch_changes()
end)
