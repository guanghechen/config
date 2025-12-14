require("bot").setup()

_G.ark = require("ark") ---@type ark
_G.dot = require("dot") ---@type dot
_G.ux = require("ux") ---@type ux

local default_storage = dot.get_default_storage() ---@type dot.context.storage
local storage = { editor = default_storage.editor, workspace = default_storage.workspace } ---@type dot.context.storage
dot.setup_context(storage)

require("ghc.plugin")

require("mason")
local action = require("ghc.action.mason")

ark.stdout.info("[guanghechen]", "Installing Mason packages...")
action.install_all(false, function()
  ark.stdout.success("[guanghechen]", "All Mason packages installed successfully!")
  local ok, err = pcall(function()
    vim.cmd("qa!")
  end)

  if not ok then
    ark.stdout.error("[guanghechen]", "Error during exit: " .. tostring(err))
    os.exit(1)
  end
end)
