local Observable = require("eve.collection.observable")
local select_item = require("eve.state.workspace.select_item")

---@class eve.state.select.data
---@field public find_buffer            eve.state.select.item.data
---@field public find_explorer          eve.state.select.item.data
---@field public find_file              eve.state.select.item.data
---@field public find_git               eve.state.select.item.data
---@field public find_highlight         eve.state.select.item.data
---@field public find_pinned_file       eve.state.select.item.data
---@field public find_python_venv       eve.state.select.item.data
---@field public find_vim_option        eve.state.select.item.data
---@field public search_file            eve.state.select.item.data
---@field public select_avante          eve.state.select.item.data
---
---@field public find_buffer_scope      eve.e.FindBufferScope
---@field public find_file_scope        eve.e.FindFileScope
---@field public search_file_scope      eve.e.SearchFileScope

---@class eve.state.select.state
---@field public find_buffer            eve.state.select.item.state
---@field public find_explorer          eve.state.select.item.state
---@field public find_file              eve.state.select.item.state
---@field public find_git               eve.state.select.item.state
---@field public find_highlight         eve.state.select.item.state
---@field public find_pinned_file       eve.state.select.item.state
---@field public find_python_venv       eve.state.select.item.state
---@field public find_vim_option        eve.state.select.item.state
---@field public search_file            eve.state.select.item.state
---@field public select_avante          eve.state.select.item.state
---
---@field public find_buffer_scope      eve.collection.IObservable<eve.e.FindBufferScope>
---@field public find_file_scope        eve.collection.IObservable<eve.e.FindFileScope>
---@field public search_file_scope      eve.collection.IObservable<eve.e.SearchFileScope>
---
---@field public find_buffer_scopes     eve.e.FindBufferScope[]
---@field public find_file_scopes       eve.e.FindFileScope[]
---@field public search_file_scopes     eve.e.SearchFileScope[]

local _state = nil ---@type eve.state.select.state | nil

---@type string[]
local keys = {
  "find_buffer",
  "find_explorer",
  "find_file",
  "find_git",
  "find_highlight",
  "find_pinned_file",
  "find_python_venv",
  "find_vim_option",
  "search_file",
  "select_avante",
}

local find_buffer_scopes = { "A", "F", "L", "T" } ---@type eve.e.FindBufferScope[]
local find_file_scopes = { "W", "C", "D" } ---@type eve.e.FindFileScope[]
local search_file_scopes = { "W", "C", "D", "B" } ---@type eve.e.SearchFileScope[]

---@class eve.state.select
---@field public keys                   string[]
---@field public find_buffer_scopes     eve.e.FindBufferScope[]
---@field public find_file_scopes       eve.e.FindFileScope[]
---@field public search_file_scopes     eve.e.SearchFileScope[]
---@field public defaults               fun(): eve.state.select.data
---@field public dump                   fun(): eve.state.select.data
---@field public load                   fun(data: unknown): eve.state.select.state
---@field public normalize              fun(data: unknown): eve.state.select.data
local M = {
  keys = keys,
  find_buffer_scopes = vim.list_slice(find_buffer_scopes),
  find_file_scopes = vim.list_slice(find_file_scopes),
  search_file_scopes = vim.list_slice(search_file_scopes),
}

---@return eve.state.select.data
function M.defaults()
  ---@type eve.state.select.data
  return {
    find_buffer = select_item.defaults(),
    find_explorer = select_item.defaults(),
    find_file = select_item.defaults(),
    find_git = select_item.defaults(),
    find_highlight = select_item.defaults(),
    find_pinned_file = select_item.defaults(),
    find_python_venv = select_item.defaults(),
    find_vim_option = select_item.defaults(),
    search_file = select_item.defaults(),
    select_avante = select_item.defaults(),

    find_buffer_scope = "A",
    find_file_scope = "C",
    search_file_scope = "C",
  }
end

---@param data                        any
---@return eve.state.select.data
function M.normalize(data)
  data = type(data) == "table" and data or {}

  ---@type eve.state.select.data
  local resolved = {
    find_buffer = select_item.normalize(data.find_buffer),
    find_explorer = select_item.normalize(data.find_explorer),
    find_file = select_item.normalize(data.find_file),
    find_git = select_item.normalize(data.find_git),
    find_highlight = select_item.normalize(data.find_highlight),
    find_pinned_file = select_item.normalize(data.find_pinned_file),
    find_python_venv = select_item.normalize(data.find_python_venv),
    find_vim_option = select_item.normalize(data.find_vim_option),
    search_file = select_item.normalize(data.search_file),
    select_avante = select_item.normalize(data.select_avante),

    find_buffer_scope = "A",
    find_file_scope = "C",
    search_file_scope = "C",
  }

  if type(data.find_buffer_scope) == "string" and vim.list_contains(find_buffer_scopes, data.find_buffer_scope) then
    resolved.find_buffer_scope = data.find_buffer_scope
  end
  if type(data.find_file_scope) == "string" and vim.list_contains(find_file_scopes, data.find_file_scope) then
    resolved.find_file_scope = data.find_file_scope
  end
  if type(data.search_file_scope) == "string" and vim.list_contains(search_file_scopes, data.search_file_scope) then
    resolved.search_file_scope = data.search_file_scope
  end
  return resolved
end

---@return eve.state.select.data
function M.dump()
  if _state == nil then
    return M.defaults()
  end

  ---@type eve.state.select.data
  return {
    find_buffer = select_item.dump(_state.find_buffer),
    find_explorer = select_item.dump(_state.find_explorer),
    find_file = select_item.dump(_state.find_file),
    find_git = select_item.dump(_state.find_git),
    find_highlight = select_item.dump(_state.find_highlight),
    find_pinned_file = select_item.dump(_state.find_pinned_file),
    find_python_venv = select_item.dump(_state.find_python_venv),
    find_vim_option = select_item.dump(_state.find_vim_option),
    search_file = select_item.dump(_state.search_file),
    select_avante = select_item.dump(_state.select_avante),

    find_buffer_scope = _state.find_buffer_scope:snapshot(),
    find_file_scope = _state.find_buffer_scope:snapshot(),
    search_file_scope = _state.search_file_scope:snapshot(),
  }
end

---@param raw_data                      any
---@return eve.state.select.state
function M.load(raw_data)
  local data = M.normalize(raw_data) ---@type eve.state.select.data

  if _state == nil then
    ---@type eve.state.select.state
    _state = {
      find_buffer = select_item.load(nil, "find_buffer", data.find_buffer),
      find_explorer = select_item.load(nil, "find_explorer", data.find_explorer),
      find_file = select_item.load(nil, "find_file", data.find_file),
      find_git = select_item.load(nil, "find_git", data.find_git),
      find_highlight = select_item.load(nil, "find_highlight", data.find_highlight),
      find_pinned_file = select_item.load(nil, "find_pinned_file", data.find_pinned_file),
      find_python_venv = select_item.load(nil, "find_python_venv", data.find_python_venv),
      find_vim_option = select_item.load(nil, "find_vim_option", data.find_vim_option),
      search_file = select_item.load(nil, "search_file", data.search_file),
      select_avante = select_item.load(nil, "select_avante", data.select_avante),

      find_buffer_scope = Observable.from_value(data.find_file_scope),
      find_file_scope = Observable.from_value(data.find_file_scope),
      search_file_scope = Observable.from_value(data.search_file_scope),

      find_buffer_scopes = vim.list_slice(find_buffer_scopes),
      find_file_scopes = vim.list_slice(find_file_scopes),
      search_file_scopes = vim.list_slice(search_file_scopes),
    }
  else
    _state.find_buffer = select_item.load(_state.find_buffer, "find_buffer", data.find_buffer)
    _state.find_explorer = select_item.load(_state.find_explorer, "find_explorer", data.find_explorer)
    _state.find_file = select_item.load(_state.find_file, "find_file", data.find_file)
    _state.find_git = select_item.load(_state.find_git, "find_git", data.find_git)
    _state.find_highlight = select_item.load(_state.find_highlight, "find_highlight", data.find_highlight)
    _state.find_pinned_file = select_item.load(_state.find_pinned_file, "find_pinned_file", data.find_pinned_file)
    _state.find_python_venv = select_item.load(_state.find_python_venv, "find_python_venv", data.find_python_venv)
    _state.find_vim_option = select_item.load(_state.find_vim_option, "find_vim_option", data.find_vim_option)
    _state.search_file = select_item.load(_state.search_file, "search_file", data.search_file)
    _state.select_avante = select_item.load(_state.select_avante, "select_avante", data.select_avante)

    _state.find_buffer_scope:next(data.find_buffer_scope)
    _state.find_file_scope:next(data.find_file_scope)
    _state.search_file_scope:next(data.search_file_scope)
  end
  return _state
end

return M
