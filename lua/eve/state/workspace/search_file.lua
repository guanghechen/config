---@class eve.state.search_file.data
---@field public flag_replace           boolean
---@field public max_filesize           string
---@field public max_matches            integer
---@field public replacement            string
---@field public search_paths           string[]

---@class eve.state.search_file.state
---@field public flag_replace           eve.collection.IObservable -- boolean>
---@field public max_filesize           eve.collection.IObservable -- string>
---@field public max_matches            eve.collection.IObservable -- integer>
---@field public replacement            eve.collection.IObservable -- string>
---@field public search_paths           eve.collection.IObservable -- string[]>

---@class eve.state.search_file : eve.state.search_file.state
---@field public defaults               fun(): eve.state.search_file.data
---@field public dump                   fun(): eve.state.search_file.data
---@field public load                   fun(data: unknown): nil
---@field public normalize              fun(data: unknown): eve.state.search_file.data
local M = {}

---@return eve.state.search_file.data
function M.defaults()
  ---@type eve.state.search_file.data
  return {
    flag_replace = false,
    max_filesize = "1M",
    max_matches = 500,
    replacement = "",
    search_paths = {},
  }
end

---@param data                        any
---@return eve.state.search_file.data
function M.normalize(data)
  local resolved = M.defaults() ---@type eve.state.search_file.data
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
    if type(data.search_paths) == "table" then
      resolved.search_paths = data.search_paths
    end
  end

  ---@type eve.state.search_file.data
  return resolved
end

---@return eve.state.search_file.data
function M.dump()
  ---@type eve.state.search_file.data
  return {
    flag_replace = M.flag_replace:snapshot(),
    max_matches = M.max_matches:snapshot(),
    max_filesize = M.max_filesize:snapshot(),
    replacement = M.replacement:snapshot(),
    search_paths = M.search_paths:snapshot(),
  }
end

---@param raw_data                      any
---@return nil
function M.load(raw_data)
  local data = M.normalize(raw_data) ---@type eve.state.search_file.data

  M.flag_replace:next(data.flag_replace)
  M.max_filesize:next(data.max_filesize)
  M.max_matches:next(data.max_matches)
  M.replacement:next(data.replacement)
  if not eve.fn.equals_list(M.search_paths:snapshot(), data.search_paths) then
    M.search_paths:next(data.search_paths)
  end
end

----------------------------------------------------------------------------------------------------

local _defaults = M.defaults() ---@type eve.state.search_file.data
M.flag_replace = eve.col.Observable.from_value(_defaults.flag_replace)
M.max_filesize = eve.col.Observable.from_value(_defaults.max_filesize)
M.max_matches = eve.col.Observable.from_value(_defaults.max_matches)
M.replacement = eve.col.Observable.from_value(_defaults.replacement)
M.search_paths = eve.col.Observable.from_value(_defaults.search_paths)

return M
