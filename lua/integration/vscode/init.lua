_G.eve = require("eve")
eve.setup_patches()
eve.setup_workspace()
require("eve.option")
require("eve.keymap")

eve.setup_state()
require("eve.autocmd-state")

require("integration.vscode.option")
require("integration.vscode.keymap")

require("fml.dressing.commentstring")

require("ghc.plugin")
pcall(require, "integration.local")
