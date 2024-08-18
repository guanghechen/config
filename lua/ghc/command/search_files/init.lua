local session = require("ghc.context.session")
local state = require("ghc.command.search_files.state")

---@class ghc.command.search_files
local M = {}

---@return nil
function M.open()
  local selected_text = fml.util.get_selected_text()
  if selected_text and #selected_text > 1 then
    local next_search_pattern = selected_text ---@type string
    session.search_flag_regex:next(false)
    session.search_pattern:next(next_search_pattern)
  end

  local search = state.get_search() ---@type fml.types.ui.search.ISearch
  search:focus()
end

---@return nil
function M.open_workspace()
  session.search_scope:next("W")
  M.open()
end

---@return nil
function M.open_cwd()
  session.search_scope:next("C")
  M.open()
end

---@return nil
function M.open_directory()
  session.search_scope:next("D")
  M.open()
end

---@return nil
function M.open_buffer()
  session.search_scope:next("B")
  M.open()
end

return M
