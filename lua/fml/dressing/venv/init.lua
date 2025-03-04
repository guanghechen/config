local __module_name__ = "fml.dressing.venv" ---@type string

local reporter = require("eve.builtin.reporter")
local venv = require("fml.dressing.venv.venv")
local hooks = require("fml.dressing.venv.hook")
local select = require("fml.dressing.venv.select")

local M = {}

M.hooks = {
  basedpyright = hooks.basedpyright_hook,
  pyright = hooks.pyright_hook,
  pylance = hooks.pylance_hook,
  pylsp = hooks.pylsp_hook,
}

function M.setup()
  vim.api.nvim_create_user_command("VenvSelect", M.open, { desc = "Activate venv" })
  vim.api.nvim_create_user_command("VenvSelectCached", M.retrieve_from_cache, { desc = "Retrieve venv from cache" })
  vim.api.nvim_create_user_command(
    "VenvSelectCurrent",
    M.venv_select_current,
    { desc = "Show currently selected venv" }
  )
end

-- Gets the system path to current active python in the venv (or nil if its not activated)
function M.get_active_path()
  return venv.current_python_path
end

-- Gets the system path to the current active venv (or nil if its not activated)
function M.get_active_venv()
  return venv.current_venv
end

-- The main function runs when user executes VenvSelect command
function M.open()
  select.open()
end

---@return nil
function M.deactivate_venv()
  venv.deactivate_venv()
end

function M.retrieve_from_cache()
  return venv.retrieve_from_cache()
end

M.venv_select_current = function()
  if M.get_active_venv() ~= nil then
    reporter.info({
      from = __module_name__,
      message = "Activated '" .. (M.get_active_venv()) .. "'",
    })
  else
    reporter.info({
      from = __module_name__,
      message = "No venv has been selected yet.",
    })
  end
end

return M
