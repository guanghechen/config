local fn = require("eve.builtin.fn")
local Observable = require("eve.collection.observable")

---@class eve.state.find.data
---@field public flag_case_sensitive    boolean
---@field public flag_gitignore         boolean
---@field public flag_fuzzy             boolean
---@field public flag_regex             boolean
---@field public includes               string[]
---@field public excludes               string[]
---@field public keyword                string
---@field public scope                  eve.e.FindScope

---@class eve.state.find.state
---@field public flag_case_sensitive    eve.collection.IObservable
---@field public flag_gitignore         eve.collection.IObservable
---@field public flag_fuzzy             eve.collection.IObservable
---@field public flag_regex             eve.collection.IObservable
---@field public includes               eve.collection.IObservable
---@field public excludes               eve.collection.IObservable
---@field public keyword                eve.collection.IObservable
---@field public scope                  eve.collection.IObservable

---@class eve.state.find
---@field public defaults               fun(): eve.state.find.data
---@field public dump                   fun(): eve.state.find.data
---@field public load                   fun(data: unknown): eve.state.find.state
---@field public normalize              fun(data: unknown): eve.state.find.data
local M = {}

local _state = nil ---@type eve.state.find.state | nil

---@return eve.state.find.data
function M.defaults()
  ---@type eve.state.find.data
  return {
    flag_case_sensitive = false,
    flag_gitignore = true,
    flag_fuzzy = false,
    flag_regex = false,
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
    scope = "C",
  }
end

---@param data                        any
---@return eve.state.find.data
function M.normalize(data)
  local resolved = M.defaults() ---@type eve.state.find.data
  if type(data) == "table" then
    if type(data.flag_case_sensitive) == "boolean" then
      resolved.flag_case_sensitive = data.flag_case_sensitive
    end
    if type(data.flag_gitignore) == "boolean" then
      resolved.flag_gitignore = data.flag_gitignore
    end
    if type(data.flag_fuzzy) == "boolean" then
      resolved.flag_fuzzy = data.flag_fuzzy
    end
    if type(data.flag_regex) == "boolean" then
      resolved.flag_regex = data.flag_regex
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
    if type(data.scope) == "string" then
      resolved.scope = data.scope
    end
  end

  ---@type eve.state.find.data
  return resolved
end

---@return eve.state.find.data
function M.dump()
  if _state == nil then
    ---@type eve.state.find.data
    return M.defaults()
  end

  ---@type eve.state.find.data
  return {
    flag_case_sensitive = _state.flag_case_sensitive:snapshot(),
    flag_gitignore = _state.flag_gitignore:snapshot(),
    flag_fuzzy = _state.flag_fuzzy:snapshot(),
    flag_regex = _state.flag_regex:snapshot(),
    includes = _state.includes:snapshot(),
    excludes = _state.excludes:snapshot(),
    keyword = _state.keyword:snapshot(),
    scope = _state.scope:snapshot(),
  }
end

---@param raw_data                      any
---@return eve.state.find.state
function M.load(raw_data)
  local data = M.normalize(raw_data) ---@type eve.state.find.data

  if _state == nil then
    ---@type eve.state.find.state
    _state = {
      flag_case_sensitive = Observable.from_value(data.flag_case_sensitive),
      flag_gitignore = Observable.from_value(data.flag_gitignore),
      flag_fuzzy = Observable.from_value(data.flag_fuzzy),
      flag_regex = Observable.from_value(data.flag_regex),
      includes = Observable.from_value(data.includes),
      excludes = Observable.from_value(data.excludes),
      keyword = Observable.from_value(data.keyword),
      scope = Observable.from_value(data.scope),
    }
    return _state
  end

  _state.flag_case_sensitive:next(data.flag_case_sensitive)
  _state.flag_gitignore:next(data.flag_gitignore)
  _state.flag_fuzzy:next(data.flag_fuzzy)
  _state.flag_regex:next(data.flag_regex)
  if not fn.equals_list(_state.includes:snapshot(), data.includes) then
    _state.includes:next(data.includes)
  end
  if not fn.equals_list(_state.excludes:snapshot(), data.excludes) then
    _state.excludes:next(data.excludes)
  end
  _state.keyword:next(data.keyword)
  _state.scope:next(data.scope)
  return _state
end

return M
