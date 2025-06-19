local context = require("fml.action.search.files.context")

local o_flag_regex = eve.context.select.search_file.flag_regex ---@type std.collection.IObservable
local o_input = eve.context.select.search_file.input ---@type std.collection.IObservable
local o_scope = eve.context.select.search_file_scope ---@type std.collection.IObservable
local o_flag_replace = eve.context.search_file.flag_replace ---@type std.collection.IObservable

---@return nil
local function focus()
  local selected_text = eve.buf.retrieve_selected_text() ---@type string
  if selected_text and #selected_text > 1 then
    local next_search_pattern = selected_text ---@type string
    o_flag_regex:next(false)
    o_input:next(next_search_pattern)
  end

  local search_context = require("fml.action.search.files.context")
  local search = search_context.get_search() ---@type eve.ux.ISearch
  search:focus()
end

---@class fml.action.search
local M = {}

---@return nil
function M.search_files()
  o_flag_replace:next(false)
  focus()
end

---@return nil
function M.search_files_in_buffer()
  o_flag_replace:next(false)
  eve.context.select.search_file_scope:next("B")
  focus()
end

---@return nil
function M.search_files_in_cwd()
  o_flag_replace:next(false)
  eve.context.select.search_file_scope:next("C")
  focus()
end

---@param specified_filepath             string|nil
---@return nil
function M.search_files_in_directory(specified_filepath)
  local silent = false ---@type boolean
  local next_scope = "D" ---@type std.e.SearchFileScope

  if specified_filepath ~= nil and #specified_filepath > 0 then
    if std.path.is_exist_dirpath(specified_filepath) then
      local dirpath = std.path.normalize(specified_filepath) ---@type string
      context.search_cwd:next(dirpath)
      silent = true
    elseif std.path.is_exist_filepath(specified_filepath) then
      local dirpath = std.path.dirname(specified_filepath) ---@type string
      context.search_cwd:next(dirpath, { force = true })
      silent = true

      eve.win.open_filepath(nil, specified_filepath)
      next_scope = "B"
    end
  end

  o_flag_replace:next(false)
  o_scope:next(next_scope, { silent = silent })
  eve.status.dirtier_statusline:mark_dirty()
  focus()
end

---@return nil
function M.search_files_in_workspace()
  o_flag_replace:next(false)
  o_scope:next("W")
  focus()
end

---@return nil
function M.replace_files()
  o_flag_replace:next(true)
  focus()
end

---@return nil
function M.replace_files_in_buffer()
  o_flag_replace:next(true)
  o_scope:next("B")
  focus()
end

---@return nil
function M.replace_files_in_cwd()
  o_flag_replace:next(true)
  o_scope:next("C")
  focus()
end

---@param specified_filepath             string|nil
---@return nil
function M.replace_files_in_directory(specified_filepath)
  local silent = false ---@type boolean
  local next_scope = "D" ---@type std.e.SearchFileScope

  if specified_filepath ~= nil and #specified_filepath > 0 then
    if std.path.is_exist_dirpath(specified_filepath) then
      local dirpath = std.path.normalize(specified_filepath) ---@type string
      context.search_cwd:next(dirpath)
      silent = true
    elseif std.path.is_exist_filepath(specified_filepath) then
      local dirpath = std.path.dirname(specified_filepath) ---@type string
      context.search_cwd:next(dirpath, { force = true })
      silent = true

      eve.win.open_filepath(nil, specified_filepath)
      next_scope = "B"
    end
  end

  o_flag_replace:next(true)
  o_scope:next(next_scope, { silent = silent })
  eve.status.dirtier_statusline:mark_dirty()
  focus()
end

---@return nil
function M.replace_files_in_workspace()
  o_flag_replace:next(true)
  o_scope:next("W")
  focus()
end

return M
