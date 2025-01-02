local functional = require("eve.builtin.functional")
local Observable = require("eve.collection.observable")

---@class eve.state.search.data
---@field public flag_case_sensitive    boolean
---@field public flag_gitignore         boolean
---@field public flag_regex             boolean
---@field public flag_replace           boolean
---@field public max_filesize           string
---@field public max_matches            integer
---@field public includes               string[]
---@field public excludes               string[]
---@field public keyword                string
---@field public replacement            string
---@field public scope                  eve.e.SearchScope
---@field public search_paths           string[]

---@class eve.state.search.state
---@field public flag_case_sensitive    eve.collection.IObservable
---@field public flag_gitignore         eve.collection.IObservable
---@field public flag_regex             eve.collection.IObservable
---@field public flag_replace           eve.collection.IObservable
---@field public max_filesize           eve.collection.IObservable
---@field public max_matches            eve.collection.IObservable
---@field public includes               eve.collection.IObservable
---@field public excludes               eve.collection.IObservable
---@field public keyword                eve.collection.IObservable
---@field public replacement            eve.collection.IObservable
---@field public scope                  eve.collection.IObservable
---@field public search_paths           eve.collection.IObservable

---@class eve.state.search
---@field public defaults               fun(): eve.state.search.data
---@field public dump                   fun(): eve.state.search.data
---@field public load                   fun(data: unknown): eve.state.search.state
---@field public normalize              fun(data: unknown): eve.state.search.data
local M = {}

local _state = nil ---@type eve.state.search.state | nil

---@return eve.state.search.data
function M.defaults()
  ---@type eve.state.search.data
  return {
    flag_case_sensitive = true,
    flag_gitignore = true,
    flag_regex = false,
    flag_replace = false,
    max_filesize = "1M",
    max_matches = 500,
    includes = {},
    excludes = {
      ".git/",
      ".cache/",
      ".next/",
      ".yarn/",
      "build/",
      "debug/",
      "node_modules/",
      "target/",
      "tmp/",
      "*.pdf",
      "*.mkv",
      "*.mp4",
      "*.zip",
    },
    keyword = "",
    replacement = "",
    scope = "C",
    search_paths = {},
  }
end

---@param data                        any
---@return eve.state.search.data
function M.normalize(data)
  local resolved = M.defaults() ---@type eve.state.search.data
  if type(data) == "table" then
    if type(data.flag_case_sensitive) == "boolean" then
      resolved.flag_case_sensitive = data.flag_case_sensitive
    end
    if type(data.flag_gitignore) == "boolean" then
      resolved.flag_gitignore = data.flag_gitignore
    end
    if type(data.flag_regex) == "boolean" then
      resolved.flag_regex = data.flag_regex
    end
    if type(data.flag_replace) == "boolean" then
      resolved.flag_replace = data.flag_replace
    end
    if type(data.max_filesize) == "string" then
      resolved.max_filesize = data.max_filesize
    end
    if type(data.max_matches) == "number" then
      resolved.max_matches = data.max_matches
    end
    if type(data.includes) == "table" then
      resolved.includes = data.includes
    end
    if type(data.excludes) == "table" then
      resolved.excludes = data.excludes
    end
    if type(data.keyword) == "string" then
      resolved.keyword = data.keyword
    end
    if type(data.replacement) == "string" then
      resolved.replacement = data.replacement
    end
    if type(data.scope) == "string" then
      resolved.scope = data.scope
    end
    if type(data.search_paths) == "table" then
      resolved.search_paths = data.search_paths
    end
  end

  ---@type eve.state.search.data
  return resolved
end

---@return eve.state.search.data
function M.dump()
  if _state == nil then
    ---@type eve.state.search.data
    return M.defaults()
  end

  ---@type eve.state.search.data
  return {
    flag_case_sensitive = _state.flag_case_sensitive:snapshot(),
    flag_gitignore = _state.flag_gitignore:snapshot(),
    flag_regex = _state.flag_regex:snapshot(),
    flag_replace = _state.flag_replace:snapshot(),
    max_matches = _state.max_matches:snapshot(),
    max_filesize = _state.max_filesize:snapshot(),
    includes = _state.includes:snapshot(),
    excludes = _state.excludes:snapshot(),
    keyword = _state.keyword:snapshot(),
    replacement = _state.replacement:snapshot(),
    scope = _state.scope:snapshot(),
    search_paths = _state.search_paths:snapshot(),
  }
end

---@param raw_data                      any
---@return eve.state.search.state
function M.load(raw_data)
  local data = M.normalize(raw_data) ---@type eve.state.search.data

  if _state == nil then
    ---@type eve.state.search.state
    _state = {
      flag_case_sensitive = Observable.from_value(data.flag_case_sensitive),
      flag_gitignore = Observable.from_value(data.flag_gitignore),
      flag_regex = Observable.from_value(data.flag_regex),
      flag_replace = Observable.from_value(data.flag_replace),
      max_filesize = Observable.from_value(data.max_filesize),
      max_matches = Observable.from_value(data.max_matches),
      includes = Observable.from_value(data.includes),
      excludes = Observable.from_value(data.excludes),
      keyword = Observable.from_value(data.keyword),
      replacement = Observable.from_value(data.replacement),
      scope = Observable.from_value(data.scope),
      search_paths = Observable.from_value(data.search_paths),
    }
    return _state
  end

  _state.flag_case_sensitive:next(data.flag_case_sensitive)
  _state.flag_gitignore:next(data.flag_gitignore)
  _state.flag_regex:next(data.flag_regex)
  _state.flag_replace:next(data.flag_replace)
  _state.max_filesize:next(data.max_filesize)
  _state.max_matches:next(data.max_matches)
  if not functional.equals_list(_state.includes:snapshot(), data.includes) then
    _state.includes:next(data.includes)
  end
  if not functional.equals_list(_state.excludes:snapshot(), data.excludes) then
    _state.excludes:next(data.excludes)
  end
  _state.keyword:next(data.keyword)
  _state.replacement:next(data.replacement)
  _state.scope:next(data.scope)
  if not functional.equals_list(_state.search_paths:snapshot(), data.search_paths) then
    _state.search_paths:next(data.search_paths)
  end
  return _state
end

return M
