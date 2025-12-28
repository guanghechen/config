pcall(require, "integration.vscode.autocmd")
pcall(require, "integration.local.autocmd")

dot.setup_context()

require("integration.vscode.option")
require("integration.vscode.keymap")
pcall(require, "integration.local.option")
pcall(require, "integration.local.keymap")

require("era.plugin")
pcall(require, "integration.local.plugin")

vim.schedule(function()
  require("era.dressing.commentstring")
  require("era.dressing.im")
  pcall(require, "integration.local.dressing")
end)
