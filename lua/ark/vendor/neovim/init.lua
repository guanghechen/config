require("dot.autocmd")
pcall(require, "ark.vendor.local.autocmd")

dot.setup_context()
require("ark.vendor.neovim.option")
require("ark.vendor.neovim.keymap")
pcall(require, "ark.vendor.local.option")
pcall(require, "ark.vendor.local.keymap")

era.m.notifier.dressing()
era.m.ui_attach.dressing()
require("era.command")

if dot.path.is_git_repo() then
  era.m.git.setup()
end

require("era.plugin")
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
  era.m.lsp.dressing()
  era.m.select.dressing()
  era.m.image.dressing()
  era.m.wk.dressing()
  era.m.paste.dressing()
  era.m.surrounds.setup()

  pcall(require, "ark.vendor.local.dressing")

  dot.setup_diagnostics()
  dot.context.watch_changes()
end)
