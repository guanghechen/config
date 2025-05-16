---@class eve.context.bookmark.data
---@field public pinned                 string[]

---@class eve.context.bookmark.state
---@field public pinned                 eve.std.collection.IObservable

---@class eve.context.bookmark : eve.context.bookmark.state
---@field public defaults               fun(): eve.context.bookmark.data
---@field public dump                   fun(): eve.context.bookmark.data
---@field public load                   fun(data: unknown): nil
---@field public normalize              fun(data: unknown): eve.context.bookmark.data
local M = {}

---@return eve.context.bookmark.data
function M.defaults()
  ---@type eve.context.bookmark.data
  return {
    pinned = {},
  }
end

---@param data                        any
---@return eve.context.bookmark.data
function M.normalize(data)
  local resolved = M.defaults() ---@type eve.context.bookmark.data
  if type(data) == "table" then
    if type(data.pinned) == "table" then
      resolved.pinned = data.pinned
    end
  end

  ---@type eve.context.bookmark.data
  return resolved
end

---@return eve.context.bookmark.data
function M.dump()
  ---@type eve.context.bookmark.data
  return {
    pinned = M.pinned:snapshot(),
  }
end

---@param raw_data                      any
---@return nil
function M.load(raw_data)
  local data = M.normalize(raw_data) ---@type eve.context.bookmark.data

  if not eve.std.fn.equals_list(M.pinned:snapshot(), data.pinned) then
    M.pinned:next(data.pinned)
  end
end

----------------------------------------------------------------------------------------------------

local _defaults = M.defaults() ---@type eve.context.bookmark.data
M.pinned = eve.std.Observable.from_value(_defaults.pinned) ---@type eve.std.collection.IObservable

return M
