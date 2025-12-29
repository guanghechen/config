---@class dot.context.behavior.data
---@field public auto_im                boolean
---@field public bufs_relative          boolean

---@class dot.context.behavior.state
---@field public auto_im                stl.c.Observable
---@field public bufs_relative          stl.c.Observable

---@class dot.context.behavior : dot.context.behavior.state
---@field public defaults               fun(): dot.context.behavior.data
---@field public dump                   fun(): dot.context.behavior.data
---@field public load                   fun(data: unknown): nil
---@field public normalize              fun(data: unknown): dot.context.behavior.data
local M = {}

---@return dot.context.behavior.data
function M.defaults()
  ---@type dot.context.behavior.data
  return {
    auto_im = true,
    bufs_relative = true,
  }
end

---@param data                          any
---@return dot.context.behavior.data
function M.normalize(data)
  local resolved = M.defaults() ---@type dot.context.behavior.data
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

---@return dot.context.behavior.data
function M.dump()
  ---@type dot.context.behavior.data
  return {
    auto_im = M.auto_im:snapshot(),
    bufs_relative = M.bufs_relative:snapshot(),
  }
end

---@param raw_data                      any
---@return nil
function M.load(raw_data)
  local data = M.normalize(raw_data) ---@type dot.context.behavior.data
  M.auto_im:next(data.auto_im)
  M.bufs_relative:next(data.bufs_relative)
end

----------------------------------------------------------------------------------------------------

local _defaults = M.defaults() ---@type dot.context.behavior.data
M.auto_im = stl.c.Observable.from_value(_defaults.auto_im)
M.bufs_relative = stl.c.Observable.from_value(_defaults.bufs_relative)
return M
