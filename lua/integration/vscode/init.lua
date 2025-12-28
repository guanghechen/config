pcall(require, "integration.vscode.autocmd")
pcall(require, "integration.local.autocmd")

dot.setup_context()

require("integration.vscode.option")
require("integration.vscode.keymap")
pcall(require, "integration.local.option")
pcall(require, "integration.local.keymap")

require("fml.plugin")
pcall(require, "integration.local.plugin")

vim.schedule(function()
  require("fml.dressing.commentstring")
  require("fml.dressing.im")
  pcall(require, "integration.local.dressing")
end)
