---@class eve.context.option.data
---@field public relativenumber         boolean

---@class eve.context.option.state
---@field public relativenumber         eve.std.collection.IObservable

---@class eve.context.option : eve.context.option.state
---@field public defaults               fun(): eve.context.option.data
---@field public dump                   fun(): eve.context.option.data
---@field public load                   fun(data: unknown): nil
---@field public normalize              fun(data: unknown): eve.context.option.data
local M = {}

---@return eve.context.option.data
function M.defaults()
  ---@type eve.context.option.data
  return {
    relativenumber = true,
  }
end

---@param data                        any
---@return eve.context.option.data
function M.normalize(data)
  local resolved = M.defaults() ---@type eve.context.option.data
  if type(data) == "table" then
    if type(data.relativenumber) == "boolean" then
      resolved.relativenumber = data.relativenumber
    end
  end

  ---@type eve.context.option.data
  return resolved
end

---@return eve.context.option.data
function M.dump()
  ---@type eve.context.option.data
  return {
    relativenumber = M.relativenumber:snapshot(),
  }
end

---@param raw_data                      any
---@return nil
function M.load(raw_data)
  local data = M.normalize(raw_data) ---@type eve.context.option.data

  M.relativenumber:next(data.relativenumber)
end

----------------------------------------------------------------------------------------------------

local _defaults = M.defaults() ---@type eve.context.option.data
M.relativenumber = eve.std.Observable.from_value(_defaults.relativenumber)

return M
