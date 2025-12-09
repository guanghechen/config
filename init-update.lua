_G.yoz = require("yoz") ---@type yoz
_G.ark = require("ark") ---@type ark
_G.dot = require("dot") ---@type dot

dot.setup_patches()
dot.setup_workspace()

_G.std = require("std") ---@type std
_G.eve = require("eve") ---@type eve
_G.ux = require("ux") ---@type ux

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
