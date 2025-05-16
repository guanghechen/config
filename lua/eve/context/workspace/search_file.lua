---@class eve.context.search_file.data
---@field public flag_replace           boolean
---@field public max_filesize           string
---@field public max_matches            integer
---@field public replacement            string

---@class eve.context.search_file.state
---@field public flag_replace           std.collection.IObservable
---@field public max_filesize           std.collection.IObservable
---@field public max_matches            std.collection.IObservable
---@field public replacement            std.collection.IObservable

---@class eve.context.search_file : eve.context.search_file.state
---@field public defaults               fun(): eve.context.search_file.data
---@field public dump                   fun(): eve.context.search_file.data
---@field public load                   fun(data: unknown): nil
---@field public normalize              fun(data: unknown): eve.context.search_file.data
local M = {}

---@return eve.context.search_file.data
function M.defaults()
  ---@type eve.context.search_file.data
  return {
    flag_replace = false,
    max_filesize = "1M",
    max_matches = 500,
    replacement = "",
  }
end

---@param data                        any
---@return eve.context.search_file.data
function M.normalize(data)
  local resolved = M.defaults() ---@type eve.context.search_file.data
  if type(data) == "table" then
    if type(data.flag_replace) == "boolean" then
      resolved.flag_replace = data.flag_replace
    end
    if type(data.max_filesize) == "string" then
      resolved.max_filesize = data.max_filesize
    end
    if type(data.max_matches) == "number" then
      resolved.max_matches = data.max_matches
    end
    if type(data.replacement) == "string" then
      resolved.replacement = data.replacement
    end
  end

  ---@type eve.context.search_file.data
  return resolved
end

---@return eve.context.search_file.data
function M.dump()
  ---@type eve.context.search_file.data
  return {
    flag_replace = M.flag_replace:snapshot(),
    max_matches = M.max_matches:snapshot(),
    max_filesize = M.max_filesize:snapshot(),
    replacement = M.replacement:snapshot(),
  }
end

---@param raw_data                      any
---@return nil
function M.load(raw_data)
  local data = M.normalize(raw_data) ---@type eve.context.search_file.data

  M.flag_replace:next(data.flag_replace)
  M.max_filesize:next(data.max_filesize)
  M.max_matches:next(data.max_matches)
  M.replacement:next(data.replacement)
end

----------------------------------------------------------------------------------------------------

local _defaults = M.defaults() ---@type eve.context.search_file.data
M.flag_replace = std.Observable.from_value(_defaults.flag_replace)
M.max_filesize = std.Observable.from_value(_defaults.max_filesize)
M.max_matches = std.Observable.from_value(_defaults.max_matches)
M.replacement = std.Observable.from_value(_defaults.replacement)

return M
