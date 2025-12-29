pcall(require, "vendor.vscode.autocmd")
pcall(require, "vendor.local.autocmd")

dot.setup_context()

require("vendor.vscode.option")
require("vendor.vscode.keymap")
pcall(require, "vendor.local.option")
pcall(require, "vendor.local.keymap")

require("era.plugin")
pcall(require, "vendor.local.plugin")

vim.schedule(function()
  require("era.dressing.commentstring")
  require("era.dressing.im")
  pcall(require, "vendor.local.dressing")
end)
