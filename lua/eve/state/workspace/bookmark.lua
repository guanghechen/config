---@class eve.state.bookmark.data
---@field public pinned                 string[]

---@class eve.state.bookmark.state
---@field public pinned                 eve.std.collection.IObservable -- string[]>

---@class eve.state.bookmark : eve.state.bookmark.state
---@field public defaults               fun(): eve.state.bookmark.data
---@field public dump                   fun(): eve.state.bookmark.data
---@field public load                   fun(data: unknown): nil
---@field public normalize              fun(data: unknown): eve.state.bookmark.data
local M = {}

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
  ---@type eve.state.bookmark.data
  return {
    pinned = M.pinned:snapshot(),
  }
end

---@param raw_data                      any
---@return nil
function M.load(raw_data)
  local data = M.normalize(raw_data) ---@type eve.state.bookmark.data

  if not eve.std.fn.equals_list(M.pinned:snapshot(), data.pinned) then
    M.pinned:next(data.pinned)
  end
end

----------------------------------------------------------------------------------------------------

local _defaults = M.defaults() ---@type eve.state.bookmark.data
M.pinned = eve.std.Observable.from_value(_defaults.pinned) ---@type eve.std.collection.IObservable -- string[]>

return M
