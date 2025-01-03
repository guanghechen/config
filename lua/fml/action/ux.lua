local command = require("eve.command")

---@class fml.action.ux
local M = {}

---@param context                       eve.command.IContext
---@param arg                           unknown|nil
---@return nil
---@diagnostic disable-next-line: unused-local
function M.reload_theme(context, arg)
  local force = type(arg) == "string" and arg:lower() == "force" ---@type boolean
  local state = require("eve.state")
  state.theme.reload_theme(force, true)
end

---@param context                       eve.command.IContext
---@return nil
function M.resume_last_widget(context)
  local state = require("eve.state")
  if not state.widget.resume() then
    command.execute(command.definitions.find.files.uuid, context)
  end
end

return M
