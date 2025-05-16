_G.eve = require("eve")
eve.setup_patches()
eve.setup_workspace()
require("eve.option")
require("eve.keymap")
pcall(require, "integration.vscode.autocmd")
pcall(require, "integration.local.autocmd")

eve.setup_context()

require("integration.vscode.option")
require("integration.vscode.keymap")
pcall(require, "integration.local.option")
pcall(require, "integration.local.keymap")

require("ghc.plugin")
pcall(require, "integration.local.plugin")

vim.schedule(function()
  require("fml.dressing.commentstring")
  require("fml.dressing.im")
  pcall(require, "integration.local.dressing")
end)
