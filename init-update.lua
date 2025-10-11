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

require("mason")
local action = require("ghc.action.mason")

std.stdout.info("[guanghechen]", "Installing Mason packages...")
action.install_all(false, function()
  std.stdout.success("[guanghechen]", "All Mason packages installed successfully!")
  local ok, err = pcall(function()
    vim.cmd("qa!")
  end)

  if not ok then
    std.stdout.error("[guanghechen]", "Error during exit: " .. tostring(err))
    os.exit(1)
  end
end)
