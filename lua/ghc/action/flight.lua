---@class ghc.action.flight
local M = {}

---@return nil
function M.toggle_autosave()
  local flag = eve.context.state.flight.autosave:snapshot() ---@type boolean
  eve.context.state.flight.autosave:next(not flag)
end

---@return nil
function M.toggle_autoload()
  local flag = eve.context.state.flight.autoload:snapshot() ---@type boolean
  eve.context.state.flight.autoload:next(not flag)
end

---@return nil
function M.toggle_copilot()
  local flag = eve.context.state.flight.copilot:snapshot() ---@type boolean
  eve.context.state.flight.copilot:next(not flag)
end

---@return nil
function M.toggle_devmode()
  local flag = eve.context.state.flight.devmode:snapshot() ---@type boolean
  eve.context.state.flight.devmode:next(not flag)
end

return M
