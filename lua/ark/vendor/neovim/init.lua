require("dot.autocmd")
pcall(require, "ark.vendor.local.autocmd")

dot.setup_context()
require("ark.vendor.neovim.option")
require("ark.vendor.neovim.keymap")
pcall(require, "ark.vendor.local.option")
pcall(require, "ark.vendor.local.keymap")

era.notifier.dressing()
require("fml.dressing.ui_attach")
require("fml.command")

if dot.path.is_git_repo() then
  require("era.git")
end

require("fml.plugin")
pcall(require, "ark.vendor.local.plugin")

---! Reload session if not specify file and current directory is a git repository.
if dot.path.is_git_repo() then
  if dot.context.flight.autoload:snapshot() then
    dot.session.load_session(dot.context.get_storage().nvim_session_autosaved)
    vim.schedule(dot.tab.refresh)
  end
end

vim.schedule(function()
  era.statusline.dressing()
  era.tabline.dressing()
  era.winline.dressing()

  era.commentstring.dressing()
  era.foldtext.dressing()
  era.scroll.dressing()
  era.statuscolumn.dressing()
  era.trailspace.dressing()
  era.virtcolumn.dressing()
  era.winsep.dressing()

  era.dim.dressing()
  era.im.dressing()
  require("fml.dressing.input")
  require("fml.dressing.lsp")
  require("fml.dressing.lsp_action")
  require("fml.dressing.python_venv")
  require("fml.dressing.select")
  era.image.dressing()
  pcall(require, "ark.vendor.local.dressing")

  dot.setup_breakpoints()
  dot.setup_diagnostics()
  dot.setup_lsp()
  dot.context.watch_changes()
end)
