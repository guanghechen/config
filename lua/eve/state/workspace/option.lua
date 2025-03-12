local Observable = require("eve.collection.observable")

---@class eve.state.option.data
---@field public relativenumber         boolean

---@class eve.state.option.state
---@field public relativenumber         eve.collection.IObservable -- boolean>

---@class eve.state.option
---@field public defaults               fun(): eve.state.option.data
---@field public dump                   fun(): eve.state.option.data
---@field public load                   fun(data: unknown): eve.state.option.state
---@field public normalize              fun(data: unknown): eve.state.option.data
local M = {}

local _state = nil ---@type eve.state.option.state | nil

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
  if _state == nil then
    ---@type eve.state.option.data
    return M.defaults()
  end

  ---@type eve.state.option.data
  return {
    relativenumber = _state.relativenumber:snapshot(),
  }
end

---@param raw_data                      any
---@return eve.state.option.state
function M.load(raw_data)
  local data = M.normalize(raw_data) ---@type eve.state.option.data

  if _state == nil then
    ---@type eve.state.option.state
    _state = {
      relativenumber = Observable.from_value(data.relativenumber),
    }
    return _state
  end

  _state.relativenumber:next(data.relativenumber)
  return _state
end

return M
