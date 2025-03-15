---@class eve.state.option.data
---@field public relativenumber         boolean

---@class eve.state.option.state
---@field public relativenumber         eve.collection.IObservable -- boolean>

---@class eve.state.option : eve.state.option.state
---@field public defaults               fun(): eve.state.option.data
---@field public dump                   fun(): eve.state.option.data
---@field public load                   fun(data: unknown): nil
---@field public normalize              fun(data: unknown): eve.state.option.data
local M = {}

---@return eve.state.option.data
function M.defaults()
  ---@type eve.state.option.data
  return {
    relativenumber = true,
  }
end

---@param data                        any
---@return eve.state.option.data
function M.normalize(data)
  local resolved = M.defaults() ---@type eve.state.option.data
  if type(data) == "table" then
    if type(data.relativenumber) == "boolean" then
      resolved.relativenumber = data.relativenumber
    end
  end

  ---@type eve.state.option.data
  return resolved
end

---@return eve.state.option.data
function M.dump()
  ---@type eve.state.option.data
  return {
    relativenumber = M.relativenumber:snapshot(),
  }
end

---@param raw_data                      any
---@return nil
function M.load(raw_data)
  local data = M.normalize(raw_data) ---@type eve.state.option.data

  M.relativenumber:next(data.relativenumber)
end

----------------------------------------------------------------------------------------------------

local _defaults = M.defaults() ---@type eve.state.option.data
M.relativenumber = eve.col.Observable.from_value(_defaults.relativenumber)

return M
