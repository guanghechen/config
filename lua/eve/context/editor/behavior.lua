---@class eve.context.behavior.data
---@field public auto_im                boolean
---@field public bufs_relative          boolean

---@class eve.context.behavior.state
---@field public auto_im                std.collection.IObservable
---@field public bufs_relative          std.collection.IObservable

---@class eve.context.behavior : eve.context.behavior.state
---@field public defaults               fun(): eve.context.behavior.data
---@field public dump                   fun(): eve.context.behavior.data
---@field public load                   fun(data: unknown): nil
---@field public normalize              fun(data: unknown): eve.context.behavior.data
local M = {}

---@return eve.context.behavior.data
function M.defaults()
  ---@type eve.context.behavior.data
  return {
    auto_im = true,
    bufs_relative = true,
  }
end

---@param data                        any
---@return eve.context.behavior.data
function M.normalize(data)
  local resolved = M.defaults() ---@type eve.context.behavior.data
  if type(data) == "table" then
    if type(data.auto_im) == "boolean" then
      resolved.auto_im = data.auto_im
    end
    if type(data.bufs_relative) == "boolean" then
      resolved.bufs_relative = data.bufs_relative
    end
  end
  return resolved
end

---@return eve.context.behavior.data
function M.dump()
  ---@type eve.context.behavior.data
  return {
    auto_im = M.auto_im:snapshot(),
    bufs_relative = M.bufs_relative:snapshot(),
  }
end

---@param raw_data                      any
---@return nil
function M.load(raw_data)
  local data = M.normalize(raw_data) ---@type eve.context.behavior.data
  M.auto_im:next(data.auto_im)
  M.bufs_relative:next(data.bufs_relative)
end

----------------------------------------------------------------------------------------------------

local _defaults = M.defaults() ---@type eve.context.behavior.data
M.auto_im = std.Observable.from_value(_defaults.auto_im)
M.bufs_relative = std.Observable.from_value(_defaults.bufs_relative)
return M
