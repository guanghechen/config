local __module_name__ = "fml.action.toggle.ai" ---@type string

local ai_providers = eve.command.definitions.toggle.ai_provider.candidates ---@type string[]
local o_ai_provider = eve.context.flight.ai_provider ---@type std.collection.IObservable

---@class fml.action.toggle.ai
local M = {}

---@param arg                           string|nil
---@return nil
function M.ai_provider(arg)
  local ai_provider = type(arg) == "string" and arg:lower() or "" ---@type string
  if vim.list_contains(ai_providers, ai_provider) then
    o_ai_provider:next(ai_provider)
  else
    vim.ui.select(ai_providers, {
      name = __module_name__,
      prompt = "Toggle Ai Provider",
      uuid_current = o_ai_provider:snapshot(),
      uuid_present = o_ai_provider:snapshot(),
      dimension = {
        row = 5,
        width = 50,
      },
    }, function(choice)
      if choice then
        o_ai_provider:next(choice)
      end
    end)
  end
end

return M
