---@class eve.context.search_buffer.data
---@field public flag_fuzzy             boolean
---@field public flag_regex             boolean
---@field public flag_replace           boolean
---@field public flag_case_sensitive    boolean
---@field public search_pattern         string
---@field public replace_pattern        string

---@class eve.context.search_buffer.state
---@field public flag_fuzzy             std.collection.IObservable
---@field public flag_regex             std.collection.IObservable
---@field public flag_replace           std.collection.IObservable
---@field public flag_case_sensitive    std.collection.IObservable
---@field public search_pattern         std.collection.IObservable
---@field public replace_pattern        std.collection.IObservable

---@class eve.context.search_buffer : eve.context.search_buffer.state
---@field public defaults               fun(): eve.context.search_buffer.data
---@field public dump                   fun(): eve.context.search_buffer.data
---@field public load                   fun(data: unknown): nil
---@field public normalize              fun(data: unknown): eve.context.search_buffer.data
local M = {}

---@return eve.context.search_buffer.data
function M.defaults()
  ---@type eve.context.search_buffer.data
  return {
    flag_fuzzy = false,
    flag_regex = false,
    flag_replace = false,
    flag_case_sensitive = true,
    search_pattern = "",
    replace_pattern = "",
  }
end

---@param data                            any
---@return eve.context.search_buffer.data
function M.normalize(data)
  local resolved = M.defaults() ---@type eve.context.search_buffer.data
  if type(data) == "table" then
    if type(data.flag_fuzzy) == "boolean" then
      resolved.flag_fuzzy = data.flag_fuzzy
    end
    if type(data.flag_regex) == "boolean" then
      resolved.flag_regex = data.flag_regex
    end
    if type(data.flag_replace) == "boolean" then
      resolved.flag_replace = data.flag_replace
    end
    if type(data.flag_case_sensitive) == "boolean" then
      resolved.flag_case_sensitive = data.flag_case_sensitive
    end
    if type(data.search_pattern) == "string" then
      resolved.search_pattern = data.search_pattern
    end
    if type(data.replace_pattern) == "string" then
      resolved.replace_pattern = data.replace_pattern
    end
  end

  ---@type eve.context.search_buffer.data
  return resolved
end

---@return eve.context.search_buffer.data
function M.dump()
  ---@type eve.context.search_buffer.data
  return {
    flag_fuzzy = M.flag_fuzzy:snapshot(),
    flag_regex = M.flag_regex:snapshot(),
    flag_replace = M.flag_replace:snapshot(),
    flag_case_sensitive = M.flag_case_sensitive:snapshot(),
    search_pattern = M.search_pattern:snapshot(),
    replace_pattern = M.replace_pattern:snapshot(),
  }
end

---@param raw_data                        any
---@return nil
function M.load(raw_data)
  local data = M.normalize(raw_data) ---@type eve.context.search_buffer.data

  M.flag_fuzzy:next(data.flag_fuzzy)
  M.flag_regex:next(data.flag_regex)
  M.flag_replace:next(data.flag_replace)
  M.flag_case_sensitive:next(data.flag_case_sensitive)
  M.search_pattern:next(data.search_pattern)
  M.replace_pattern:next(data.replace_pattern)
end

----------------------------------------------------------------------------------------------------

local _defaults = M.defaults() ---@type eve.context.search_buffer.data
M.flag_fuzzy = std.Observable.from_value(_defaults.flag_fuzzy)
M.flag_regex = std.Observable.from_value(_defaults.flag_regex)
M.flag_replace = std.Observable.from_value(_defaults.flag_replace)
M.flag_case_sensitive = std.Observable.from_value(_defaults.flag_case_sensitive)
M.search_pattern = std.Observable.from_value(_defaults.search_pattern)
M.replace_pattern = std.Observable.from_value(_defaults.replace_pattern)

return M

