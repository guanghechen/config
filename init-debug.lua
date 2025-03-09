_G.eve = require("eve")
eve.setup_patches()
eve.setup_workspace()
require("eve.option")
require("eve.keymap")
require("integration.neovim.autocmd")

local default_storage = eve.get_default_storage() ---@type eve.state.storage
local storage = { editor = default_storage.editor } ---@type eve.state.storage
eve.setup_state(storage)
require("eve.autocmd-state")
require("integration.neovim.keymap")

eve.setup_theme()

require("fml.command")
require("fml.dressing.hipairs")
require("fml.dressing.commentstring")
require("fml.dressing.illumniate")
require("fml.dressing.input")
require("fml.dressing.nvimbar.statusline")
require("fml.dressing.nvimbar.tabline")
require("fml.dressing.nvimbar.winline")
require("fml.dressing.python_venv")
require("fml.dressing.select")
require("fml.dressing.winsep")

require("ghc.command")
