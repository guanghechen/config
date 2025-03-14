_G.eve = require("eve")
eve.setup_patches()
eve.setup_workspace()
require("eve.option")

local default_storage = eve.get_default_storage() ---@type eve.state.storage
local storage = { editor = default_storage.editor, workspace = default_storage.workspace } ---@type eve.state.storage
eve.setup_state(storage)

require("ghc.plugin")
vim.cmd("qa")
