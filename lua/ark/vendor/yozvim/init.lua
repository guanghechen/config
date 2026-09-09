-- Yozvim: minimal Neovim integration

pcall(require, "ark.vendor.local.autocmd")

dot.setup_context()

require("ark.vendor.yozvim.option")
require("ark.vendor.yozvim.keymap")
pcall(require, "ark.vendor.local.option")
pcall(require, "ark.vendor.local.keymap")

require("era.plugin")
pcall(require, "ark.vendor.local.plugin")

vim.schedule(function()
  era.dressing.setup({ "commentstring" })

  era.m.splitjoin.dressing()
  era.m.surrounds.setup()

  pcall(require, "ark.vendor.local.dressing")
end)
