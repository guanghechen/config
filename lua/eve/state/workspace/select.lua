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
---@field public find_buffer_scope      eve.collection.IObservable -- eve.e.FindBufferScope>
---@field public find_file_scope        eve.collection.IObservable -- eve.e.FindFileScope>
---@field public search_file_scope      eve.collection.IObservable -- eve.e.SearchFileScope>

---@class eve.state.select : eve.state.select.state
---@field public keys                   string[]
---@field public find_buffer_scopes     eve.e.FindBufferScope[]
---@field public find_file_scopes       eve.e.FindFileScope[]
---@field public search_file_scopes     eve.e.SearchFileScope[]
---
---@field public defaults               fun(): eve.state.select.data
---@field public dump                   fun(): eve.state.select.data
---@field public load                   fun(data: unknown): nil
---@field public normalize              fun(data: unknown): eve.state.select.data
local M = {}

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

  if type(data.find_buffer_scope) == "string" and vim.list_contains(M.find_buffer_scopes, data.find_buffer_scope) then
    resolved.find_buffer_scope = data.find_buffer_scope
  end
  if type(data.find_file_scope) == "string" and vim.list_contains(M.find_file_scopes, data.find_file_scope) then
    resolved.find_file_scope = data.find_file_scope
  end
  if type(data.search_file_scope) == "string" and vim.list_contains(M.search_file_scopes, data.search_file_scope) then
    resolved.search_file_scope = data.search_file_scope
  end
  return resolved
end

---@return eve.state.select.data
function M.dump()
  ---@type eve.state.select.data
  return {
    find_buffer = select_item.dump(M.find_buffer),
    find_explorer = select_item.dump(M.find_explorer),
    find_file = select_item.dump(M.find_file),
    find_git = select_item.dump(M.find_git),
    find_highlight = select_item.dump(M.find_highlight),
    find_pinned_file = select_item.dump(M.find_pinned_file),
    find_python_venv = select_item.dump(M.find_python_venv),
    find_vim_option = select_item.dump(M.find_vim_option),
    search_file = select_item.dump(M.search_file),
    select_avante = select_item.dump(M.select_avante),

    find_buffer_scope = M.find_buffer_scope:snapshot(),
    find_file_scope = M.find_buffer_scope:snapshot(),
    search_file_scope = M.search_file_scope:snapshot(),
  }
end

---@param raw_data                      any
---@return nil
function M.load(raw_data)
  local data = M.normalize(raw_data) ---@type eve.state.select.data

  M.find_buffer = select_item.load(M.find_buffer, "find_buffer", data.find_buffer)
  M.find_explorer = select_item.load(M.find_explorer, "find_explorer", data.find_explorer)
  M.find_file = select_item.load(M.find_file, "find_file", data.find_file)
  M.find_git = select_item.load(M.find_git, "find_git", data.find_git)
  M.find_highlight = select_item.load(M.find_highlight, "find_highlight", data.find_highlight)
  M.find_pinned_file = select_item.load(M.find_pinned_file, "find_pinned_file", data.find_pinned_file)
  M.find_python_venv = select_item.load(M.find_python_venv, "find_python_venv", data.find_python_venv)
  M.find_vim_option = select_item.load(M.find_vim_option, "find_vim_option", data.find_vim_option)
  M.search_file = select_item.load(M.search_file, "search_file", data.search_file)
  M.select_avante = select_item.load(M.select_avante, "select_avante", data.select_avante)

  M.find_buffer_scope:next(data.find_buffer_scope)
  M.find_file_scope:next(data.find_file_scope)
  M.search_file_scope:next(data.search_file_scope)
end

----------------------------------------------------------------------------------------------------

local _defaults = M.defaults() ---@type eve.state.select.data
M.find_buffer = select_item.load(nil, "find_buffer", _defaults.find_buffer)
M.find_explorer = select_item.load(nil, "find_explorer", _defaults.find_explorer)
M.find_file = select_item.load(nil, "find_file", _defaults.find_file)
M.find_git = select_item.load(nil, "find_git", _defaults.find_git)
M.find_highlight = select_item.load(nil, "find_highlight", _defaults.find_highlight)
M.find_pinned_file = select_item.load(nil, "find_pinned_file", _defaults.find_pinned_file)
M.find_python_venv = select_item.load(nil, "find_python_venv", _defaults.find_python_venv)
M.find_vim_option = select_item.load(nil, "find_vim_option", _defaults.find_vim_option)
M.search_file = select_item.load(nil, "search_file", _defaults.search_file)
M.select_avante = select_item.load(nil, "select_avante", _defaults.select_avante)

M.find_buffer_scope = eve.col.Observable.from_value(_defaults.find_file_scope)
M.find_file_scope = eve.col.Observable.from_value(_defaults.find_file_scope)
M.search_file_scope = eve.col.Observable.from_value(_defaults.search_file_scope)

---@return string[]
M.keys = {
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
M.find_buffer_scopes = { "A", "F", "L", "T" } ---@type eve.e.FindBufferScope[]
M.find_file_scopes = { "W", "C", "D" } ---@type eve.e.FindFileScope[]
M.search_file_scopes = { "W", "C", "D", "B" } ---@type eve.e.SearchFileScope[]

return M
