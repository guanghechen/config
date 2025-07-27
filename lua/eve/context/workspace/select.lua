local select_item = require("eve.context.workspace.select_item")

---@class eve.context.select.data
---@field public find_buffer            eve.context.select.item.data
---@field public find_diagnostics       eve.context.select.item.data
---@field public find_explorer          eve.context.select.item.data
---@field public find_file              eve.context.select.item.data
---@field public find_git               eve.context.select.item.data
---@field public find_highlight         eve.context.select.item.data
---@field public find_pinned_file       eve.context.select.item.data
---@field public find_python_venv       eve.context.select.item.data
---@field public find_vim_option        eve.context.select.item.data
---@field public lsp_reference          eve.context.select.item.data
---@field public lsp_symbols            eve.context.select.item.data
---@field public search_file            eve.context.select.item.data
---
---@field public find_buffer_scope      std.e.FindBufferScope
---@field public find_file_scope        std.e.FindFileScope
---@field public search_file_scope      std.e.SearchFileScope

---@class eve.context.select.state
---@field public find_buffer            eve.context.select.item.state
---@field public find_diagnostics       eve.context.select.item.state
---@field public find_explorer          eve.context.select.item.state
---@field public find_file              eve.context.select.item.state
---@field public find_git               eve.context.select.item.state
---@field public find_highlight         eve.context.select.item.state
---@field public find_pinned_file       eve.context.select.item.state
---@field public find_python_venv       eve.context.select.item.state
---@field public find_vim_option        eve.context.select.item.state
---@field public lsp_reference          eve.context.select.item.state
---@field public lsp_symbols            eve.context.select.item.state
---@field public search_file            eve.context.select.item.state
---
---@field public find_buffer_scope      std.collection.IObservable
---@field public find_file_scope        std.collection.IObservable
---@field public search_file_scope      std.collection.IObservable

---@class eve.context.select : eve.context.select.state
---@field public keys                   string[]
---@field public find_buffer_scopes     std.e.FindBufferScope[]
---@field public find_file_scopes       std.e.FindFileScope[]
---@field public search_file_scopes     std.e.SearchFileScope[]
---
---@field public defaults               fun(): eve.context.select.data
---@field public dump                   fun(): eve.context.select.data
---@field public load                   fun(data: unknown): nil
---@field public normalize              fun(data: unknown): eve.context.select.data
local M = {}

---@return eve.context.select.data
function M.defaults()
  ---@type eve.context.select.data
  return {
    find_buffer = select_item.defaults(),
    find_diagnostics = select_item.defaults(),
    find_explorer = select_item.defaults(),
    find_file = select_item.defaults(),
    find_git = select_item.defaults(),
    find_highlight = select_item.defaults(),
    find_pinned_file = select_item.defaults(),
    find_python_venv = select_item.defaults(),
    find_vim_option = select_item.defaults(),
    lsp_reference = select_item.defaults(),
    lsp_symbols = select_item.defaults(),
    search_file = select_item.defaults(),

    find_buffer_scope = "A",
    find_file_scope = "C",
    search_file_scope = "C",
  }
end

---@param data                        any
---@return eve.context.select.data
function M.normalize(data)
  data = type(data) == "table" and data or {}

  ---@type eve.context.select.data
  local resolved = {
    find_buffer = select_item.normalize(data.find_buffer),
    find_diagnostics = select_item.normalize(data.find_diagnostics),
    find_explorer = select_item.normalize(data.find_explorer),
    find_file = select_item.normalize(data.find_file),
    find_git = select_item.normalize(data.find_git),
    find_highlight = select_item.normalize(data.find_highlight),
    find_pinned_file = select_item.normalize(data.find_pinned_file),
    find_python_venv = select_item.normalize(data.find_python_venv),
    find_vim_option = select_item.normalize(data.find_vim_option),
    lsp_reference = select_item.normalize(data.lsp_reference),
    lsp_symbols = select_item.normalize(data.lsp_symbols),
    search_file = select_item.normalize(data.search_file),

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

---@return eve.context.select.data
function M.dump()
  ---@type eve.context.select.data
  return {
    find_buffer = select_item.dump(M.find_buffer),
    find_diagnostics = select_item.dump(M.find_diagnostics),
    find_explorer = select_item.dump(M.find_explorer),
    find_file = select_item.dump(M.find_file),
    find_git = select_item.dump(M.find_git),
    find_highlight = select_item.dump(M.find_highlight),
    find_pinned_file = select_item.dump(M.find_pinned_file),
    find_python_venv = select_item.dump(M.find_python_venv),
    find_vim_option = select_item.dump(M.find_vim_option),
    lsp_reference = select_item.dump(M.lsp_reference),
    lsp_symbols = select_item.dump(M.lsp_symbols),
    search_file = select_item.dump(M.search_file),

    find_buffer_scope = M.find_buffer_scope:snapshot(),
    find_file_scope = M.find_buffer_scope:snapshot(),
    search_file_scope = M.search_file_scope:snapshot(),
  }
end

---@param raw_data                      any
---@return nil
function M.load(raw_data)
  local data = M.normalize(raw_data) ---@type eve.context.select.data

  M.find_buffer = select_item.load(M.find_buffer, "find_buffer", data.find_buffer)
  M.find_diagnostics = select_item.load(M.find_diagnostics, "find_diagnostics", data.find_diagnostics)
  M.find_explorer = select_item.load(M.find_explorer, "find_explorer", data.find_explorer)
  M.find_file = select_item.load(M.find_file, "find_file", data.find_file)
  M.find_git = select_item.load(M.find_git, "find_git", data.find_git)
  M.find_highlight = select_item.load(M.find_highlight, "find_highlight", data.find_highlight)
  M.find_pinned_file = select_item.load(M.find_pinned_file, "find_pinned_file", data.find_pinned_file)
  M.find_python_venv = select_item.load(M.find_python_venv, "find_python_venv", data.find_python_venv)
  M.find_vim_option = select_item.load(M.find_vim_option, "find_vim_option", data.find_vim_option)
  M.lsp_reference = select_item.load(M.lsp_reference, "lsp_reference", data.lsp_reference)
  M.lsp_symbols = select_item.load(M.lsp_symbols, "lsp_symbols", data.lsp_symbols)
  M.search_file = select_item.load(M.search_file, "search_file", data.search_file)

  M.find_buffer_scope:next(data.find_buffer_scope)
  M.find_file_scope:next(data.find_file_scope)
  M.search_file_scope:next(data.search_file_scope)
end

----------------------------------------------------------------------------------------------------

local _defaults = M.defaults() ---@type eve.context.select.data
M.find_buffer = select_item.load(nil, "find_buffer", _defaults.find_buffer)
M.find_diagnostics = select_item.load(nil, "find_diagnostics", _defaults.find_diagnostics)
M.find_explorer = select_item.load(nil, "find_explorer", _defaults.find_explorer)
M.find_file = select_item.load(nil, "find_file", _defaults.find_file)
M.find_git = select_item.load(nil, "find_git", _defaults.find_git)
M.find_highlight = select_item.load(nil, "find_highlight", _defaults.find_highlight)
M.find_pinned_file = select_item.load(nil, "find_pinned_file", _defaults.find_pinned_file)
M.find_python_venv = select_item.load(nil, "find_python_venv", _defaults.find_python_venv)
M.find_vim_option = select_item.load(nil, "find_vim_option", _defaults.find_vim_option)
M.lsp_reference = select_item.load(nil, "lsp_reference", _defaults.lsp_reference)
M.lsp_symbols = select_item.load(nil, "lsp_symbols", _defaults.lsp_symbols)
M.search_file = select_item.load(nil, "search_file", _defaults.search_file)

M.find_buffer_scope = std.Observable.from_value(_defaults.find_file_scope)
M.find_file_scope = std.Observable.from_value(_defaults.find_file_scope)
M.search_file_scope = std.Observable.from_value(_defaults.search_file_scope)

---@return string[]
M.keys = {
  "find_buffer",
  "find_diagnostics",
  "find_explorer",
  "find_file",
  "find_git",
  "find_highlight",
  "find_pinned_file",
  "find_python_venv",
  "find_vim_option",
  "lsp_reference",
  "lsp_symbols",
  "search_file",
}
M.find_buffer_scopes = { "A", "F", "L", "T" } ---@type std.e.FindBufferScope[]
M.find_file_scopes = { "W", "C", "D" } ---@type std.e.FindFileScope[]
M.search_file_scopes = { "W", "C", "D", "B" } ---@type std.e.SearchFileScope[]

return M
