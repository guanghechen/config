local state = require("ghc.action.search_files.state")

---@class ghc.action.search_files
local M = {}

---@return nil
function M.open_search()
  local selected_text = eve.util.get_selected_text()
  if selected_text and #selected_text > 1 then
    local next_search_pattern = selected_text ---@type string
    eve.context.state.search.flag_regex:next(false)
    eve.context.state.search.keyword:next(next_search_pattern)
  end

  eve.context.state.search.flag_replace:next(false)
  local search = state.get_search() ---@type t.fml.ux.search.ISearch
  search:focus()
end

---@return nil
function M.open_replace()
  local selected_text = eve.util.get_selected_text()
  if selected_text and #selected_text > 1 then
    local next_keyword = selected_text ---@type string
    eve.context.state.search.flag_regex:next(false)
    eve.context.state.search.keyword(next_keyword)
  end

  eve.context.state.search_flag_replace:next(true)
  local search = state.get_search() ---@type t.fml.ux.search.ISearch
  search:focus()
end

---@return nil
function M.open_search_workspace()
  eve.context.state.search.scope:next("W")
  M.open_search()
end

---@return nil
function M.open_search_cwd()
  eve.context.state.search.scope:next("C")
  M.open_search()
end

---@return nil
function M.open_search_directory()
  eve.context.state.search.scope:next("D")
  M.open_search()
end

---@return nil
function M.open_search_buffer()
  eve.context.state.search.scope:next("B")
  M.open_search()
end

---@return nil
function M.open_replace_workspace()
  eve.context.state.search.scope:next("W")
  M.open_replace()
end

---@return nil
function M.open_replace_cwd()
  eve.context.state.search.scope:next("C")
  M.open_replace()
end

---@return nil
function M.open_replace_directory()
  eve.context.state.search.scope:next("D")
  M.open_replace()
end

---@return nil
function M.open_replace_buffer()
  eve.context.state.search.scope:next("B")
  M.open_replace()
end

return M
