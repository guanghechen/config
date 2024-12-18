local Observable = require("eve.lib.collection.observable")

---@class eve.state.theme.data
---@field public theme                  eve.e.Theme
---@field public transparency           boolean
---@field public relativenumber         boolean

---@class eve.state.theme.state
---@field public theme                  eve.lib.collection.IObservable
---@field public transparency           eve.lib.collection.IObservable
---@field public relativenumber         eve.lib.collection.IObservable

---@class eve.state.theme
---@field public defaults               fun(): eve.state.theme.data
---@field public dump                   fun(): eve.state.theme.data
---@field public load                   fun(data: unknown): eve.state.theme.state
---@field public normalize              fun(data: unknown): eve.state.theme.data
local M = {}

local _state = nil ---@type eve.state.theme.state | nil

---@return eve.state.theme.data
function M.defaults()
  ---@type eve.state.theme.data
  return {
    theme = "gruvbox_dark",
    transparency = false,
    relativenumber = true,
  }
end

---@param data                        any
---@return eve.state.theme.data
function M.normalize(data)
  local resolved = M.defaults() ---@type eve.state.theme.data
  if type(data) == "table" then
    if type(data.theme) == "string" then
      resolved.theme = data.theme
    end
    if type(data.transparency) == "boolean" then
      resolved.transparency = data.transparency
    end
    if type(data.relativenumber) == "boolean" then
      resolved.relativenumber = data.relativenumber
    end
  end

  ---@type eve.state.theme.data
  return resolved
end

---@return eve.state.theme.data
function M.dump()
  if _state == nil then
    ---@type eve.state.theme.data
    return M.defaults()
  end

  ---@type eve.state.theme.data
  return {
    theme = _state.theme:snapshot(),
    transparency = _state.transparency:snapshot(),
    relativenumber = _state.relativenumber:snapshot(),
  }
end

---@param raw_data                      any
---@return eve.state.theme.state
function M.load(raw_data)
  local data = M.normalize(raw_data) ---@type eve.state.theme.data
  if _state == nil then
    ---@type eve.state.theme.state
    _state = {
      theme = Observable.from_value(data.theme),
      transparency = Observable.from_value(data.transparency),
      relativenumber = Observable.from_value(data.relativenumber),
    }
    return _state
  end

  _state.theme:next(data.theme)
  _state.transparency:next(data.transparency)
  _state.relativenumber:next(data.relativenumber)
  return _state
end

return M
