require("std.bootstrap").setup_patches()
require("std.bootstrap").setup_workspace()

_G.std = require("std")
_G.oxi = require("oxi")
_G.eve = require("eve")
require("eve.option")

local default_storage = eve.get_default_storage() ---@type eve.context.storage
local storage = { editor = default_storage.editor, workspace = default_storage.workspace } ---@type eve.context.storage
eve.setup_context(storage)

require("ghc.plugin")
vim.cmd("qa")
