local get_selected_text = require("eve.lib.nvim").get_selected_text
local state = require("eve.state")
local context = require("fml.action.search.files.context")

---@return nil
local function focus()
  local selected_text = get_selected_text()
  if selected_text and #selected_text > 1 then
    local next_search_pattern = selected_text ---@type string
    state.search.flag_regex:next(false)
    state.search.keyword:next(next_search_pattern)
  end

  local search = context.get_search() ---@type fml.ux.search.ISearch
  search:focus()
end

---@class fml.action.search
local M = {}

---@return nil
function M.search_files()
  state.search.flag_replace:next(false)
  focus()
end

---@return nil
function M.search_files_in_buffer()
  state.search.flag_replace:next(false)
  state.search.scope:next("B")
  focus()
end

---@return nil
function M.search_files_in_cwd()
  state.search.flag_replace:next(false)
  state.search.scope:next("C")
  focus()
end

---@return nil
function M.search_files_in_directory()
  state.search.flag_replace:next(false)
  state.search.scope:next("D")
  focus()
end

---@return nil
function M.search_files_in_workspace()
  state.search.flag_replace:next(false)
  state.search.scope:next("W")
  focus()
end

---@return nil
function M.replace_files()
  state.search.flag_replace:next(true)
  focus()
end

---@return nil
function M.replace_files_in_buffer()
  state.search.flag_replace:next(true)
  state.search.scope:next("B")
  focus()
end

---@return nil
function M.replace_files_in_cwd()
  state.search.flag_replace:next(true)
  state.search.scope:next("C")
  focus()
end

---@return nil
function M.replace_files_in_directory()
  state.search.flag_replace:next(true)
  state.search.scope:next("D")
  focus()
end

---@return nil
function M.replace_files_in_workspace()
  state.search.flag_replace:next(true)
  state.search.scope:next("W")
  focus()
end

return M
