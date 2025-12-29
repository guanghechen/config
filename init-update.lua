require("bot").setup()

local default_storage = dot.get_default_storage() ---@type dot.context.storage
local storage = { editor = default_storage.editor, workspace = default_storage.workspace } ---@type dot.context.storage
dot.setup_context(storage)

require("era.plugin")

require("mason")
local action = require("era.action.plugin.mason")

stl.stdout.info("[guanghechen]", "Installing Mason packages...")
action.install_all(false, function()
  stl.stdout.success("[guanghechen]", "All Mason packages installed successfully!")
  local ok, err = pcall(function()
    vim.cmd("qa!")
  end)

  if not ok then
    stl.stdout.error("[guanghechen]", "Error during exit: " .. tostring(err))
    os.exit(1)
  end
end)
