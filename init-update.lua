require("ark.bootstrap").setup()

local default_storage = dot.get_default_storage() ---@type dot.context.storage
local storage = { editor = default_storage.editor, workspace = default_storage.workspace } ---@type dot.context.storage
dot.setup_context(storage)

require("era.plugin")

local Action = require("era.m.plugin.action")
Action.install():map(function()
  -- A plugin that failed to install makes the update exit non-zero, so its caller can tell.
  local failed = Action.get_progress().error ---@type integer
  local ok, err = pcall(function()
    vim.cmd(failed > 0 and "cquit 1" or "qa!")
  end)

  if not ok then
    stl.stdout.error("[guanghechen]", "Error during exit: " .. tostring(err))
    os.exit(1)
  end
end)
