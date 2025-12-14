---@class dot.context.bookmark.data
---@field public pinned                 string[]

---@class dot.context.bookmark.state
---@field public pinned                 ark.c.Observable

---@class dot.context.bookmark : dot.context.bookmark.state
---@field public defaults               fun(): dot.context.bookmark.data
---@field public dump                   fun(): dot.context.bookmark.data
---@field public load                   fun(data: unknown): nil
---@field public normalize              fun(data: unknown): dot.context.bookmark.data
local M = {}

---@return dot.context.bookmark.data
function M.defaults()
  ---@type dot.context.bookmark.data
  return {
    pinned = {},
  }
end

---@param data                          any
---@return dot.context.bookmark.data
function M.normalize(data)
  local resolved = M.defaults() ---@type dot.context.bookmark.data
  if type(data) == "table" then
    if type(data.pinned) == "table" then
      resolved.pinned = data.pinned
    end
  end

  ---@type dot.context.bookmark.data
  return resolved
end

---@return dot.context.bookmark.data
function M.dump()
  ---@type dot.context.bookmark.data
  return {
    pinned = M.pinned:snapshot(),
  }
end

---@param raw_data                      any
---@return nil
function M.load(raw_data)
  local data = M.normalize(raw_data) ---@type dot.context.bookmark.data

  if not ark.fn.equals_list(M.pinned:snapshot(), data.pinned) then
    M.pinned:next(data.pinned)
  end
end

----------------------------------------------------------------------------------------------------

local _defaults = M.defaults() ---@type dot.context.bookmark.data
M.pinned = ark.c.Observable.from_value(_defaults.pinned) ---@type ark.c.Observable

return M
