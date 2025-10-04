---@diagnostic disable: invisible
local __module_name__ = "fml.action.search.buffer" ---@type string

local searcher ---@type eve.ux.searcher.buffer.Searcher|nil

---@class fml.action.search.buffer
local M = {}

---@return nil
function M.search_in_buffer()
  local tabnr = vim.api.nvim_get_current_tabpage() ---@type integer
  local winnr_sourcefile = eve.tab.retrieve_winnr_sourcefile(tabnr) ---@type integer|nil
  if winnr_sourcefile == nil or not vim.api.nvim_win_is_valid(winnr_sourcefile) then
    std.reporter.warn({
      from = __module_name__,
      message = "No valid source file window in current tab",
    })
    return
  end

  if searcher == nil then
    local context = eve.context.search_buffer ---@type eve.context.search_buffer
    searcher = eve.ux.searcher.BufferSearcher.new({
      o_flag_fuzzy = context.flag_fuzzy,
      o_flag_regex = context.flag_regex,
      o_flag_replace = context.flag_replace,
      o_flag_case_sensitive = context.flag_case_sensitive,
      o_search_pattern = context.search_pattern,
      o_replace_pattern = context.replace_pattern,
    })
  end

  local winnr_finder = searcher:get_winnr_finder() ---@type integer|nil
  local winnr_current = vim.api.nvim_get_current_win() ---@type integer
  if winnr_finder == winnr_current then
    searcher:close()
  else
    searcher:attach(winnr_sourcefile)
  end
end

---@return eve.ux.searcher.buffer.Searcher|nil
function M.get_searcher()
  return searcher
end

return M
