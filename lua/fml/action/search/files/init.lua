local context = require("fml.action.search.files.context")

---@return nil
local function focus()
  local selected_text = eve.editor.get_selected_text() ---@type string
  if selected_text and #selected_text > 1 then
    local next_search_pattern = selected_text ---@type string
    eve.state.select.search_file.flag_regex:next(false)
    eve.state.select.search_file.input:next(next_search_pattern)
  end

  local search_context = require("fml.action.search.files.context")
  local search = search_context.get_search() ---@type eve.ux.ISearch
  search:show()
end

---@class fml.action.search
local M = {}

---@return nil
function M.search_files()
  eve.state.search_file.flag_replace:next(false)
  focus()
end

---@return nil
function M.search_files_in_buffer()
  eve.state.search_file.flag_replace:next(false)
  eve.state.select.search_file_scope:next("B")
  focus()
end

---@return nil
function M.search_files_in_cwd()
  eve.state.search_file.flag_replace:next(false)
  eve.state.select.search_file_scope:next("C")
  focus()
end

---@param specified_filepath             string|nil
---@return nil
function M.search_files_in_directory(specified_filepath)
  local silent = false ---@type boolean
  local next_scope = "D" ---@type eve.e.SearchFileScope

  if specified_filepath ~= nil and #specified_filepath > 0 then
    if eve.path.is_exist_dirpath(specified_filepath) then
      local dirpath = eve.path.normalize(specified_filepath) ---@type string
      context.search_cwd:next(dirpath)
      silent = true
    elseif eve.path.is_exist_filepath(specified_filepath) then
      local dirpath = eve.path.dirname(specified_filepath) ---@type string
      context.search_cwd:next(dirpath, { force = true })
      silent = true

      eve.win.open_filepath(nil, specified_filepath)
      next_scope = "B"
    end
  end

  eve.state.search_file.flag_replace:next(false)
  eve.state.select.search_file_scope:next(next_scope, { silent = silent })
  eve.state.status.dirtier_statusline:mark_dirty()
  focus()
end

---@return nil
function M.search_files_in_workspace()
  eve.state.search_file.flag_replace:next(false)
  eve.state.select.search_file_scope:next("W")
  focus()
end

---@return nil
function M.replace_files()
  eve.state.search_file.flag_replace:next(true)
  focus()
end

---@return nil
function M.replace_files_in_buffer()
  eve.state.search_file.flag_replace:next(true)
  eve.state.select.search_file_scope:next("B")
  focus()
end

---@return nil
function M.replace_files_in_cwd()
  eve.state.search_file.flag_replace:next(true)
  eve.state.select.search_file_scope:next("C")
  focus()
end

---@param specified_filepath             string|nil
---@return nil
function M.replace_files_in_directory(specified_filepath)
  local silent = false ---@type boolean
  local next_scope = "D" ---@type eve.e.SearchFileScope

  if specified_filepath ~= nil and #specified_filepath > 0 then
    if eve.path.is_exist_dirpath(specified_filepath) then
      local dirpath = eve.path.normalize(specified_filepath) ---@type string
      context.search_cwd:next(dirpath)
      silent = true
    elseif eve.path.is_exist_filepath(specified_filepath) then
      local dirpath = eve.path.dirname(specified_filepath) ---@type string
      context.search_cwd:next(dirpath, { force = true })
      silent = true

      eve.win.open_filepath(nil, specified_filepath)
      next_scope = "B"
    end
  end

  eve.state.search_file.flag_replace:next(true)
  eve.state.select.search_file_scope:next(next_scope, { silent = silent })
  eve.state.status.dirtier_statusline:mark_dirty()
  focus()
end

---@return nil
function M.replace_files_in_workspace()
  eve.state.search_file.flag_replace:next(true)
  eve.state.select.search_file_scope:next("W")
  focus()
end

return M
