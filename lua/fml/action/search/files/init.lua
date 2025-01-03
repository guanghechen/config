local fn = require("eve.builtin.fn")
local state = require("eve.state")

---@return nil
local function focus()
  local selected_text = fn.get_selected_text()
  if selected_text and #selected_text > 1 then
    local next_search_pattern = selected_text ---@type string
    state.search.flag_regex:next(false)
    state.search.keyword:next(next_search_pattern)
  end

  local context = require("fml.action.search.files.context")
  local search = context.get_search() ---@type fml.ux.search.ISearch
  search:focus()
end

---@class fml.action.search
local M = {}

---@param context                       eve.command.IContext
---@return nil
---@diagnostic disable-next-line: unused-local
function M.search_files(context)
  state.search.flag_replace:next(false)
  focus()
end

---@param context                       eve.command.IContext
---@return nil
---@diagnostic disable-next-line: unused-local
function M.search_files_in_buffer(context)
  state.search.flag_replace:next(false)
  state.search.scope:next("B")
  focus()
end

---@param context                       eve.command.IContext
---@return nil
---@diagnostic disable-next-line: unused-local
function M.search_files_in_cwd(context)
  state.search.flag_replace:next(false)
  state.search.scope:next("C")
  focus()
end

---@param context                       eve.command.IContext
---@return nil
---@diagnostic disable-next-line: unused-local
function M.search_files_in_directory(context)
  state.search.flag_replace:next(false)
  state.search.scope:next("D")
  focus()
end

---@param context                       eve.command.IContext
---@return nil
---@diagnostic disable-next-line: unused-local
function M.search_files_in_workspace(context)
  state.search.flag_replace:next(false)
  state.search.scope:next("W")
  focus()
end

---@param context                       eve.command.IContext
---@return nil
---@diagnostic disable-next-line: unused-local
function M.replace_files(context)
  state.search.flag_replace:next(true)
  focus()
end

---@param context                       eve.command.IContext
---@return nil
---@diagnostic disable-next-line: unused-local
function M.replace_files_in_buffer(context)
  state.search.flag_replace:next(true)
  state.search.scope:next("B")
  focus()
end

---@param context                       eve.command.IContext
---@return nil
---@diagnostic disable-next-line: unused-local
function M.replace_files_in_cwd(context)
  state.search.flag_replace:next(true)
  state.search.scope:next("C")
  focus()
end

---@param context                       eve.command.IContext
---@return nil
---@diagnostic disable-next-line: unused-local
function M.replace_files_in_directory(context)
  state.search.flag_replace:next(true)
  state.search.scope:next("D")
  focus()
end

---@param context                       eve.command.IContext
---@return nil
---@diagnostic disable-next-line: unused-local
function M.replace_files_in_workspace(context)
  state.search.flag_replace:next(true)
  state.search.scope:next("W")
  focus()
end

return M
