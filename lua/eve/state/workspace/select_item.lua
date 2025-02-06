local fn = require("eve.builtin.fn")
local History = require("eve.collection.history")
local Observable = require("eve.collection.observable")

---@class eve.state.select.item.data
---@field public flag_case_sensitive    boolean
---@field public flag_gitignore         boolean
---@field public flag_fuzzy             boolean
---@field public flag_regex             boolean
---@field public flag_selected          boolean
---@field public includes               string[]
---@field public excludes               string[]
---@field public input                  string
---@field public input_history          eve.collection.history.ISerializedData

---@class eve.state.select.item.state
---@field public flag_case_sensitive    eve.collection.IObservable
---@field public flag_gitignore         eve.collection.IObservable
---@field public flag_fuzzy             eve.collection.IObservable
---@field public flag_regex             eve.collection.IObservable
---@field public flag_selected          eve.collection.IObservable
---@field public includes               eve.collection.IObservable
---@field public excludes               eve.collection.IObservable
---@field public input                  eve.collection.IObservable
---@field public input_history          eve.collection.IHistory

---@class eve.state.select.item
---@field public defaults               fun(): eve.state.select.item.data
---@field public normalize              fun(data: unknown): eve.state.select.item.data
---@field public dump                   fun(state: eve.state.select.item.state): eve.state.select.item.data
---@field public load                   fun(state: eve.state.select.item.state|nil, name: string, data: unknown): eve.state.select.item.state
local M = {}

---@return eve.state.select.item.data
function M.defaults()
  ---@type eve.state.select.item.data
  return {
    flag_case_sensitive = false,
    flag_gitignore = true,
    flag_fuzzy = false,
    flag_regex = false,
    flag_selected = false,
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
    input = "",
    input_history = { present = 0, stack = {} },
  }
end

---@param data                        any
---@return eve.state.select.item.data
function M.normalize(data)
  local resolved = M.defaults() ---@type eve.state.select.item.data
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
    if type(data.flag_selected) == "boolean" then
      resolved.flag_selected = data.flag_selected
    end
    if type(data.includes) == "table" then
      resolved.includes = data.includes
    end
    if type(data.excludes) == "table" then
      resolved.excludes = data.excludes
    end
    if type(data.input) == "string" then
      resolved.input = data.input
    end
    if type(data.input_history) == "table" then
      if type(data.input_history.present) == "number" then
        resolved.input_history.present = data.input_history.present
      end
      if type(data.input_history.stack) == "table" then
        resolved.input_history.stack = data.input_history.stack
      end
    end
  end

  ---@type eve.state.select.item.data
  return resolved
end

---@param state                         eve.state.select.item.state
---@return eve.state.select.item.data
function M.dump(state)
  ---@type eve.state.select.item.data
  return {
    flag_case_sensitive = state.flag_case_sensitive:snapshot(),
    flag_gitignore = state.flag_gitignore:snapshot(),
    flag_fuzzy = state.flag_fuzzy:snapshot(),
    flag_regex = state.flag_regex:snapshot(),
    flag_selected = state.flag_selected:snapshot(),
    includes = state.includes:snapshot(),
    excludes = state.excludes:snapshot(),
    input = state.input:snapshot(),
    input_history = state.input_history:dump(),
  }
end

---@param state                         eve.state.select.item.state|nil
---@param name                          string
---@param raw_data                      any
---@return eve.state.select.item.state
function M.load(state, name, raw_data)
  local data = M.normalize(raw_data) ---@type eve.state.select.item.data

  if state == nil then
    ---@type eve.state.select.item.state
    state = {
      flag_case_sensitive = Observable.from_value(data.flag_case_sensitive),
      flag_gitignore = Observable.from_value(data.flag_gitignore),
      flag_fuzzy = Observable.from_value(data.flag_fuzzy),
      flag_regex = Observable.from_value(data.flag_regex),
      flag_selected = Observable.from_value(data.flag_selected),
      includes = Observable.from_value(data.includes),
      excludes = Observable.from_value(data.excludes),
      input = Observable.from_value(data.input),
      input_history = History.deserialize({
        name = name,
        capacity = 100,
        data = data.input_history,
      }),
    }
    return state
  end

  state.flag_case_sensitive:next(data.flag_case_sensitive)
  state.flag_gitignore:next(data.flag_gitignore)
  state.flag_fuzzy:next(data.flag_fuzzy)
  state.flag_regex:next(data.flag_regex)
  state.flag_selected:next(data.flag_selected)
  if not fn.equals_list(state.includes:snapshot(), data.includes) then
    state.includes:next(data.includes)
  end
  if not fn.equals_list(state.excludes:snapshot(), data.excludes) then
    state.excludes:next(data.excludes)
  end
  state.input:next(data.input)
  state.input_history:load(data.input_history)
  return state
end

return M
