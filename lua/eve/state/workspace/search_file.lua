local Observable = require("eve.collection.observable")

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

---@class eve.state.search_file
---@field public defaults               fun(): eve.state.search_file.data
---@field public dump                   fun(): eve.state.search_file.data
---@field public load                   fun(data: unknown): eve.state.search_file.state
---@field public normalize              fun(data: unknown): eve.state.search_file.data
local M = {}

local _state = nil ---@type eve.state.search_file.state | nil

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
  if _state == nil then
    ---@type eve.state.search_file.data
    return M.defaults()
  end

  ---@type eve.state.search_file.data
  return {
    flag_replace = _state.flag_replace:snapshot(),
    max_matches = _state.max_matches:snapshot(),
    max_filesize = _state.max_filesize:snapshot(),
    replacement = _state.replacement:snapshot(),
    search_paths = _state.search_paths:snapshot(),
  }
end

---@param raw_data                      any
---@return eve.state.search_file.state
function M.load(raw_data)
  local data = M.normalize(raw_data) ---@type eve.state.search_file.data

  if _state == nil then
    ---@type eve.state.search_file.state
    _state = {
      flag_replace = Observable.from_value(data.flag_replace),
      max_filesize = Observable.from_value(data.max_filesize),
      max_matches = Observable.from_value(data.max_matches),
      replacement = Observable.from_value(data.replacement),
      search_paths = Observable.from_value(data.search_paths),
    }
    return _state
  end

  _state.flag_replace:next(data.flag_replace)
  _state.max_filesize:next(data.max_filesize)
  _state.max_matches:next(data.max_matches)
  _state.replacement:next(data.replacement)
  if not eve.std.fn.equals_list(_state.search_paths:snapshot(), data.search_paths) then
    _state.search_paths:next(data.search_paths)
  end
  return _state
end

return M
