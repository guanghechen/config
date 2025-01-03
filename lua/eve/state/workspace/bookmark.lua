local fn = require("eve.builtin.fn")
local Observable = require("eve.collection.observable")

---@class eve.state.bookmark.data
---@field public pinned                 string[]

---@class eve.state.bookmark.state
---@field public pinned                 eve.collection.IObservable

---@class eve.state.bookmark
---@field public defaults               fun(): eve.state.bookmark.data
---@field public dump                   fun(): eve.state.bookmark.data
---@field public load                   fun(data: unknown): eve.state.bookmark.state
---@field public normalize              fun(data: unknown): eve.state.bookmark.data
local M = {}

local _state = nil ---@type eve.state.bookmark.state | nil

---@return eve.state.bookmark.data
function M.defaults()
  ---@type eve.state.bookmark.data
  return {
    pinned = {},
  }
end

---@param data                        any
---@return eve.state.bookmark.data
function M.normalize(data)
  local resolved = M.defaults() ---@type eve.state.bookmark.data
  if type(data) == "table" then
    if type(data.pinned) == "table" then
      resolved.pinned = data.pinned
    end
  end

  ---@type eve.state.bookmark.data
  return resolved
end

---@return eve.state.bookmark.data
function M.dump()
  if _state == nil then
    ---@type eve.state.bookmark.data
    return M.defaults()
  end

  ---@type eve.state.bookmark.data
  return {
    pinned = _state.pinned:snapshot(),
  }
end

---@param raw_data                      any
---@return eve.state.bookmark.state
function M.load(raw_data)
  local data = M.normalize(raw_data) ---@type eve.state.bookmark.data

  if _state == nil then
    ---@type eve.state.bookmark.state
    _state = {
      pinned = Observable.from_value(data.pinned),
    }
    return _state
  end

  if not fn.equals_list(_state.pinned:snapshot(), data.pinned) then
    _state.pinned:next(data.pinned)
  end
  return _state
end

return M
