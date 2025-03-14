local state = require("eve.state")

---@return nil
local function focus()
  local selected_text = eve.editor.get_selected_text() ---@type string
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

---@return nil
function M.search_files()
  state.search_file.flag_replace:next(false)
  focus()
end

---@return nil
function M.search_files_in_buffer()
  state.search_file.flag_replace:next(false)
  state.select.search_file_scope:next("B")
  focus()
end

---@return nil
function M.search_files_in_cwd()
  state.search_file.flag_replace:next(false)
  state.select.search_file_scope:next("C")
  focus()
end

---@return nil
function M.search_files_in_directory()
  state.search_file.flag_replace:next(false)
  state.select.search_file_scope:next("D")
  focus()
end

---@return nil
function M.search_files_in_workspace()
  state.search_file.flag_replace:next(false)
  state.select.search_file_scope:next("W")
  focus()
end

---@return nil
function M.replace_files()
  state.search_file.flag_replace:next(true)
  focus()
end

---@return nil
function M.replace_files_in_buffer()
  state.search_file.flag_replace:next(true)
  state.select.search_file_scope:next("B")
  focus()
end

---@return nil
function M.replace_files_in_cwd()
  state.search_file.flag_replace:next(true)
  state.select.search_file_scope:next("C")
  focus()
end

---@return nil
function M.replace_files_in_directory()
  state.search_file.flag_replace:next(true)
  state.select.search_file_scope:next("D")
  focus()
end

---@return nil
function M.replace_files_in_workspace()
  state.search_file.flag_replace:next(true)
  state.select.search_file_scope:next("W")
  focus()
end

return M
