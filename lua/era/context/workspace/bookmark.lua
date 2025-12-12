---@class era.context.bookmark.data
---@field public pinned                 string[]

---@class era.context.bookmark.state
---@field public pinned                 ark.c.Observable

---@class era.context.bookmark : era.context.bookmark.state
---@field public defaults               fun(): era.context.bookmark.data
---@field public dump                   fun(): era.context.bookmark.data
---@field public load                   fun(data: unknown): nil
---@field public normalize              fun(data: unknown): era.context.bookmark.data
local M = {}

---@return era.context.bookmark.data
function M.defaults()
  ---@type era.context.bookmark.data
  return {
    pinned = {},
  }
end

---@param data                          any
---@return era.context.bookmark.data
function M.normalize(data)
  local resolved = M.defaults() ---@type era.context.bookmark.data
  if type(data) == "table" then
    if type(data.pinned) == "table" then
      resolved.pinned = data.pinned
    end
  end

  ---@type era.context.bookmark.data
  return resolved
end

---@return era.context.bookmark.data
function M.dump()
  ---@type era.context.bookmark.data
  return {
    pinned = M.pinned:snapshot(),
  }
end

---@param raw_data                      any
---@return nil
function M.load(raw_data)
  local data = M.normalize(raw_data) ---@type era.context.bookmark.data

  if not ark.fn.equals_list(M.pinned:snapshot(), data.pinned) then
    M.pinned:next(data.pinned)
  end
end

----------------------------------------------------------------------------------------------------

local _defaults = M.defaults() ---@type era.context.bookmark.data
M.pinned = ark.c.Observable.from_value(_defaults.pinned) ---@type ark.c.Observable

return M
