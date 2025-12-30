require("dot.autocmd")
pcall(require, "ark.vendor.local.autocmd")

dot.setup_context()
require("ark.vendor.neovide.option")
require("ark.vendor.neovide.keymap")
pcall(require, "ark.vendor.local.option")
pcall(require, "ark.vendor.local.keymap")

era.m.notifier.dressing()
era.m.ui_attach.dressing()
require("fml.command")

if dot.path.is_git_repo() then
  require("era.m.git")
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
  era.m.statusline.dressing()
  era.m.tabline.dressing()
  era.m.winline.dressing()

  era.m.commentstring.dressing()
  era.m.foldtext.dressing()
  era.m.scroll.dressing()
  era.m.statuscolumn.dressing()
  era.m.trailspace.dressing()
  era.m.virtcolumn.dressing()
  era.m.winsep.dressing()

  era.m.dim.dressing()
  era.m.im.dressing()
  era.m.input.dressing()
  require("fml.dressing.lsp")
  require("fml.dressing.lsp_action")
  era.m.python_venv.dressing()
  require("fml.dressing.select")
  era.m.image.dressing()
  pcall(require, "ark.vendor.neovide.dressing")
  pcall(require, "ark.vendor.local.dressing")

  dot.setup_breakpoints()
  dot.setup_diagnostics()
  dot.setup_lsp()
  dot.context.watch_changes()
end)
