local Observable = require("eve.collection.observable")

---@class eve.state.find_buffer.data
---@field public flag_case_sensitive    boolean
---@field public flag_fuzzy             boolean
---@field public flag_regex             boolean
---@field public keyword                string
---@field public scope                  eve.e.FindBufferScope

---@class eve.state.find_buffer.state
---@field public flag_case_sensitive    eve.collection.IObservable
---@field public flag_fuzzy             eve.collection.IObservable
---@field public flag_regex             eve.collection.IObservable
---@field public keyword                eve.collection.IObservable
---@field public scope                  eve.collection.IObservable

---@class eve.state.find_buffer
---@field public defaults               fun(): eve.state.find_buffer.data
---@field public dump                   fun(): eve.state.find_buffer.data
---@field public load                   fun(data: unknown): eve.state.find_buffer.state
---@field public normalize              fun(data: unknown): eve.state.find_buffer.data
local M = {}

local _state = nil ---@type eve.state.find_buffer.state | nil

---@return eve.state.find_buffer.data
function M.defaults()
  ---@type eve.state.find_buffer.data
  return {
    flag_case_sensitive = false,
    flag_fuzzy = true,
    flag_regex = false,
    keyword = "",
    scope = "P",
  }
end

---@param data                        any
---@return eve.state.find_buffer.data
function M.normalize(data)
  local resolved = M.defaults() ---@type eve.state.find_buffer.data
  if type(data) == "table" then
    if type(data.flag_case_sensitive) == "boolean" then
      resolved.flag_case_sensitive = data.flag_case_sensitive
    end
    if type(data.flag_fuzzy) == "boolean" then
      resolved.flag_fuzzy = data.flag_fuzzy
    end
    if type(data.flag_regex) == "boolean" then
      resolved.flag_regex = data.flag_regex
    end
    if type(data.keyword) == "string" then
      resolved.keyword = data.keyword
    end
    if type(data.scope) == "string" then
      resolved.scope = data.scope
    end
  end

  ---@type eve.state.find_buffer.data
  return resolved
end

---@return eve.state.find_buffer.data
function M.dump()
  if _state == nil then
    ---@type eve.state.find_buffer.data
    return M.defaults()
  end

  ---@type eve.state.find_buffer.data
  return {
    flag_case_sensitive = _state.flag_case_sensitive:snapshot(),
    flag_fuzzy = _state.flag_fuzzy:snapshot(),
    flag_regex = _state.flag_regex:snapshot(),
    keyword = _state.keyword:snapshot(),
    scope = _state.scope:snapshot(),
  }
end

---@param raw_data                      any
---@return eve.state.find_buffer.state
function M.load(raw_data)
  local data = M.normalize(raw_data) ---@type eve.state.find_buffer.data

  if _state == nil then
    ---@type eve.state.find_buffer.state
    _state = {
      flag_case_sensitive = Observable.from_value(data.flag_case_sensitive),
      flag_fuzzy = Observable.from_value(data.flag_fuzzy),
      flag_regex = Observable.from_value(data.flag_regex),
      keyword = Observable.from_value(data.keyword),
      scope = Observable.from_value(data.scope),
    }
    return _state
  end

  _state.flag_case_sensitive:next(data.flag_case_sensitive)
  _state.flag_fuzzy:next(data.flag_fuzzy)
  _state.flag_regex:next(data.flag_regex)
  _state.keyword:next(data.keyword)
  _state.scope:next(data.scope)
  return _state
end

return M
