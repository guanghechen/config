require("dot.autocmd")
pcall(require, "ark.vendor.local.autocmd")

dot.setup_context()
require("ark.vendor.neovide.option")
require("ark.vendor.neovide.keymap")
pcall(require, "ark.vendor.local.option")
pcall(require, "ark.vendor.local.keymap")

era.m.notifier.dressing()
era.m.ui_attach.dressing()
era.m.im.dressing()
require("era.command")

if dot.path.is_git_repo() then
  era.m.git.setup()
end

require("era.plugin")
pcall(require, "ark.vendor.neovide.plugin")
pcall(require, "ark.vendor.local.plugin")

vim.schedule(function()
  era.m.statusline.dressing()
  era.m.tabline.dressing()
  era.m.winline.dressing()

  era.m.commentstring.dressing()
  era.m.foldtext.dressing()
  era.dressing.indentscope.dressing()
  era.m.scroll.dressing()
  era.m.statuscolumn.dressing()
  era.m.trailspace.dressing()
  era.m.virtcolumn.dressing()
  era.m.winsep.dressing()

  era.m.dim.dressing()
  era.m.input.dressing()
  era.m.lsp.dressing()
  era.m.select.dressing()
  era.m.image.dressing()
  era.m.wk.dressing()
  era.m.paste.dressing()
  era.m.splitjoin.dressing()
  era.m.surrounds.setup()

  pcall(require, "ark.vendor.neovide.dressing")
  pcall(require, "ark.vendor.local.dressing")

  dot.setup_diagnostics()
  dot.context.watch_changes()
end)
