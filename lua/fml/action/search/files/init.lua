local editor = require("eve.module.editor")
local state = require("eve.state")

---@param context                       eve.command.IContext
---@return nil
local function focus(context)
  local selected_text = context.selected_text or editor.get_selected_text() ---@type string
  if selected_text and #selected_text > 1 then
    local next_search_pattern = selected_text ---@type string
    state.select.search_file.flag_regex:next(false)
    state.select.search_file.input:next(next_search_pattern)
  end

  local search_context = require("fml.action.search.files.context")
  local search = search_context.get_search() ---@type fml.ux.search.ISearch
  search:show()
end

---@class fml.action.search
local M = {}

---@param context                       eve.command.IContext
---@return nil
function M.search_files(context)
  state.search_file.flag_replace:next(false)
  focus(context)
end

---@param context                       eve.command.IContext
---@return nil
function M.search_files_in_buffer(context)
  state.search_file.flag_replace:next(false)
  state.select.search_file_scope:next("B")
  focus(context)
end

---@param context                       eve.command.IContext
---@return nil
function M.search_files_in_cwd(context)
  state.search_file.flag_replace:next(false)
  state.select.search_file_scope:next("C")
  focus(context)
end

---@param context                       eve.command.IContext
---@return nil
function M.search_files_in_directory(context)
  state.search_file.flag_replace:next(false)
  state.select.search_file_scope:next("D")
  focus(context)
end

---@param context                       eve.command.IContext
---@return nil
function M.search_files_in_workspace(context)
  state.search_file.flag_replace:next(false)
  state.select.search_file_scope:next("W")
  focus(context)
end

---@param context                       eve.command.IContext
---@return nil
function M.replace_files(context)
  state.search_file.flag_replace:next(true)
  focus(context)
end

---@param context                       eve.command.IContext
---@return nil
function M.replace_files_in_buffer(context)
  state.search_file.flag_replace:next(true)
  state.select.search_file_scope:next("B")
  focus(context)
end

---@param context                       eve.command.IContext
---@return nil
function M.replace_files_in_cwd(context)
  state.search_file.flag_replace:next(true)
  state.select.search_file_scope:next("C")
  focus(context)
end

---@param context                       eve.command.IContext
---@return nil
function M.replace_files_in_directory(context)
  state.search_file.flag_replace:next(true)
  state.select.search_file_scope:next("D")
  focus(context)
end

---@param context                       eve.command.IContext
---@return nil
function M.replace_files_in_workspace(context)
  state.search_file.flag_replace:next(true)
  state.select.search_file_scope:next("W")
  focus(context)
end

return M
