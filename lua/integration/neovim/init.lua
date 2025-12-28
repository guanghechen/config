require("dot.autocmd")
pcall(require, "integration.local.autocmd")

dot.setup_context()
require("integration.neovim.option")
require("integration.neovim.keymap")
pcall(require, "integration.local.option")
pcall(require, "integration.local.keymap")

require("fml.dressing.notifier")
require("fml.dressing.ui_attach")
require("fml.command")

if dot.path.is_git_repo() then
  require("dot.module.git")
end

require("fml.plugin")
pcall(require, "integration.local.plugin")

---! Reload session if not specify file and current directory is a git repository.
if dot.path.is_git_repo() then
  if dot.context.flight.autoload:snapshot() then
    dot.session.load_session(dot.context.get_storage().nvim_session_autosaved)
    vim.schedule(dot.tab.refresh)
  end
end

vim.schedule(function()
  require("fml.dressing.statusline")
  require("fml.dressing.tabline")
  require("fml.dressing.winline")

  require("fml.dressing.commentstring")
  require("fml.dressing.foldtext")
  require("fml.dressing.scroll")
  require("fml.dressing.statuscolumn")
  require("fml.dressing.trailspace")
  require("fml.dressing.virtcolumn")
  require("fml.dressing.winsep")

  require("fml.dressing.dim")
  require("fml.dressing.im")
  require("fml.dressing.input")
  require("fml.dressing.lsp")
  require("fml.dressing.lsp_action")
  require("fml.dressing.python_venv")
  require("fml.dressing.select")
  require("fml.dressing.image")
  pcall(require, "integration.local.dressing")

  dot.setup_breakpoints()
  dot.setup_diagnostics()
  dot.setup_lsp()
  dot.context.watch_changes()
end)
