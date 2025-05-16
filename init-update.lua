_G.std = require("std")
_G.eve = require("eve")
eve.setup_patches()
eve.setup_workspace()
require("eve.option")

local default_storage = eve.get_default_storage() ---@type eve.context.storage
local storage = { editor = default_storage.editor, workspace = default_storage.workspace } ---@type eve.context.storage
eve.setup_context(storage)

require("ghc.plugin")
vim.cmd("qa")
