local Observable = require("eve.lib.collection.observable")

---@class eve.t.state.bookmark.data
---@field public pinned                 string[]

---@class eve.t.state.bookmark.state
---@field public pinned                 eve.lib.collection.IObservable

---@class eve.t.state.bookmark
---@field public defaults               fun(): eve.t.state.bookmark.data
---@field public dump                   fun(): eve.t.state.bookmark.data
---@field public load                   fun(data: unknown): nil
---@field public normalize              fun(data: unknown): eve.t.state.bookmark.data
---@field public snapshot               fun(): eve.t.state.bookmark.state | nil

---@return eve.t.state.bookmark
local M = {}

local _state = nil ---@type eve.t.state.bookmark.state | nil

---@return eve.t.state.bookmark.data
function M.defaults()
  return {
    pinned = {},
  }
end

---@param data                        any
---@return eve.t.state.data.bookmark
function M.normalize(data)
  local resolved = M.bookmark.defaults() ---@type eve.t.state.data.bookmark
  if type(data) == "table" then
    if type(data.pinned) == "table" then
      resolved.pinned = data.pinned
    end
  end

  ---@type eve.t.state.data.bookmark
  return resolved
end

---@return eve.t.state.bookmark.data
function M.dump()
  if _state == nil then
    ---@type eve.t.state.bookmark.data
    return M.defaults()
  end

  ---@type eve.t.state.bookmark.data
  return {
    pinned = _state.pinned:snapshot(),
  }
end

---@param data                        eve.t.state.bookmark.data
---@return nil
function M.load(data)
  ---@type eve.t.state.bookmark.state
  return {
    pinned = Observable.from_value(data.pinned),
  }
end

---@return eve.t.state.bookmark.state|nil
function M.snapshot()
  return _state
end

return M
