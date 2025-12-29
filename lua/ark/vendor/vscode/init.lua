pcall(require, "ark.vendor.vscode.autocmd")
pcall(require, "ark.vendor.local.autocmd")

dot.setup_context()

require("ark.vendor.vscode.option")
require("ark.vendor.vscode.keymap")
pcall(require, "ark.vendor.local.option")
pcall(require, "ark.vendor.local.keymap")

require("fml.plugin")
pcall(require, "ark.vendor.local.plugin")

vim.schedule(function()
  require("fml.dressing.commentstring")
  require("fml.dressing.im")
  pcall(require, "ark.vendor.local.dressing")
end)
