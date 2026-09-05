require("dot.autocmd")
pcall(require, "ark.vendor.local.autocmd")

dot.setup_context()
require("ark.vendor.neovim.option")
require("ark.vendor.neovim.keymap")
pcall(require, "ark.vendor.local.option")
pcall(require, "ark.vendor.local.keymap")

era.dressing.setup({ "notifier", "ui_attach" })
era.m.im.dressing()
require("era.command")

if dot.path.is_git_repo() then
  era.m.git.setup()
end

require("era.plugin")
pcall(require, "ark.vendor.local.plugin")

vim.schedule(function()
  era.dressing.setup({
    "statusline",
    "tabline",
    "winline",
    "commentstring",
    "foldtext",
    "indentline",
    "indentscope",
    "hipattern",
    "scroll",
    "statuscolumn",
    "trailspace",
    "virtcolumn",
    "winsep",
  })

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
