require("dot.autocmd")
pcall(require, "ark.vendor.local.autocmd")

dot.setup_context()
require("ark.vendor.neovide.option")
require("ark.vendor.neovide.keymap")
pcall(require, "ark.vendor.local.option")
pcall(require, "ark.vendor.local.keymap")

require("fml.dressing.notifier")
require("fml.dressing.ui_attach")
require("fml.command")

if dot.path.is_git_repo() then
  require("dot.module.git")
end

require("fml.plugin")
pcall(require, "ark.vendor.neovide.plugin")
pcall(require, "ark.vendor.local.plugin")

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
  pcall(require, "ark.vendor.neovide.dressing")
  pcall(require, "ark.vendor.local.dressing")

  dot.setup_breakpoints()
  dot.setup_diagnostics()
  dot.setup_lsp()
  dot.context.watch_changes()
end)
