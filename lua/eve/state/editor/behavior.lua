---@class eve.state.behavior.data
---@field public auto_im                boolean

---@class eve.state.behavior.state
---@field public auto_im                eve.std.collection.IObservable -- boolean>

---@class eve.state.behavior : eve.state.behavior.state
---@field public defaults               fun(): eve.state.behavior.data
---@field public dump                   fun(): eve.state.behavior.data
---@field public load                   fun(data: unknown): nil
---@field public normalize              fun(data: unknown): eve.state.behavior.data
local M = {}

---@return eve.state.behavior.data
function M.defaults()
  ---@type eve.state.behavior.data
  return {
    auto_im = true,
  }
end

---@param data                        any
---@return eve.state.behavior.data
function M.normalize(data)
  local resolved = M.defaults() ---@type eve.state.behavior.data
  if type(data) == "table" then
    if type(data.auto_im) == "boolean" then
      resolved.auto_im = data.auto_im
    end
  end
  return resolved
end

---@return eve.state.behavior.data
function M.dump()
  ---@type eve.state.behavior.data
  return {
    auto_im = M.auto_im:snapshot(),
  }
end

---@param raw_data                      any
---@return nil
function M.load(raw_data)
  local data = M.normalize(raw_data) ---@type eve.state.behavior.data
  M.auto_im:next(data.auto_im)
end

----------------------------------------------------------------------------------------------------

local _defaults = M.defaults() ---@type eve.state.behavior.data
M.auto_im = eve.std.Observable.from_value(_defaults.auto_im)
return M
