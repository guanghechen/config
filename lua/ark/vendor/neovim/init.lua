require("dot.autocmd")
pcall(require, "ark.vendor.local.autocmd")

dot.setup_context()
require("ark.vendor.neovim.option")
require("ark.vendor.neovim.keymap")
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
pcall(require, "ark.vendor.local.plugin")

vim.schedule(function()
  era.dressing.statusline.dressing()
  era.dressing.tabline.dressing()
  era.m.winline.dressing()

  era.dressing.commentstring.dressing()
  era.dressing.foldtext.dressing()
  era.dressing.indentline.dressing()
  era.dressing.indentscope.dressing()
  era.dressing.hipattern.dressing()
  era.dressing.scroll.dressing()
  era.dressing.statuscolumn.dressing()
  era.dressing.trailspace.dressing()
  era.dressing.virtcolumn.dressing()
  era.dressing.winsep.dressing()

  era.m.dim.dressing()
  era.m.input.dressing()
  era.m.lsp.dressing()
  era.m.select.dressing()
  era.m.image.dressing()
  era.m.wk.dressing()
  era.m.paste.dressing()
  era.m.splitjoin.dressing()
  era.m.surrounds.setup()

  pcall(require, "ark.vendor.local.dressing")

  dot.setup_diagnostics()
  dot.context.watch_changes()
end)
