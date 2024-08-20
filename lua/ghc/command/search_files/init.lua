local session = require("ghc.context.session")
local state = require("ghc.command.search_files.state")

---@class ghc.command.search_files
local M = {}

---@return nil
function M.open_search()
  local selected_text = fml.util.get_selected_text()
  if selected_text and #selected_text > 1 then
    local next_search_pattern = selected_text ---@type string
    session.search_flag_regex:next(false)
    session.search_pattern:next(next_search_pattern)
  end

  session.search_flag_replace:next(false)
  local search = state.get_search() ---@type fml.types.ui.search.ISearch
  search:focus()
end

---@return nil
function M.open_replace()
  local selected_text = fml.util.get_selected_text()
  if selected_text and #selected_text > 1 then
    local next_search_pattern = selected_text ---@type string
    session.search_flag_regex:next(false)
    session.search_pattern:next(next_search_pattern)
  end

  session.search_flag_replace:next(true)
  local search = state.get_search() ---@type fml.types.ui.search.ISearch
  search:focus()
end

---@return nil
function M.open_search_workspace()
  session.search_scope:next("W")
  M.open_search()
end

---@return nil
function M.open_search_cwd()
  session.search_scope:next("C")
  M.open_search()
end

---@return nil
function M.open_search_directory()
  session.search_scope:next("D")
  M.open_search()
end

---@return nil
function M.open_search_buffer()
  session.search_scope:next("B")
  M.open_search()
end

---@return nil
function M.open_replace_workspace()
  session.search_scope:next("W")
  M.open_replace()
end

---@return nil
function M.open_replace_cwd()
  session.search_scope:next("C")
  M.open_replace()
end

---@return nil
function M.open_replace_directory()
  session.search_scope:next("D")
  M.open_replace()
end

---@return nil
function M.open_replace_buffer()
  session.search_scope:next("B")
  M.open_replace()
end

return M
