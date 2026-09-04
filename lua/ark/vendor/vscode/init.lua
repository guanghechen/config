pcall(require, "ark.vendor.local.autocmd")

dot.setup_context()

require("ark.vendor.vscode.option")
require("ark.vendor.vscode.keymap")
pcall(require, "ark.vendor.local.option")
pcall(require, "ark.vendor.local.keymap")

require("era.plugin")
pcall(require, "ark.vendor.local.plugin")

vim.schedule(function()
  era.dressing.commentstring.dressing()
  -- era.m.im.dressing()
  era.m.splitjoin.dressing()
  era.m.surrounds.setup()

  pcall(require, "ark.vendor.local.dressing")
end)
