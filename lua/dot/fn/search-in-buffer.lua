---@diagnostic disable: invisible
local __module_name__ = "dot.fn.search_in_buffer" ---@type string

local searcher ---@type dot.module.searcher.buffer.Searcher|nil

---@return nil
local function search_in_buffer()
  local tabnr = vim.api.nvim_get_current_tabpage() ---@type integer
  local winnr_sourcefile = dot.tab.retrieve_winnr_sourcefile(tabnr) ---@type integer|nil
  if winnr_sourcefile == nil or not vim.api.nvim_win_is_valid(winnr_sourcefile) then
    ark.reporter.warn({
      from = __module_name__,
      message = "No valid source file window in current tab",
    })
    return
  end

  if searcher == nil then
    local context = dot.context.search_buffer ---@type dot.context.search_buffer
    searcher = dot.searcher.BufferSearcher.new({
      o_flag_fuzzy = context.flag_fuzzy,
      o_flag_regex = context.flag_regex,
      o_flag_replace = context.flag_replace,
      o_flag_case_sensitive = context.flag_case_sensitive,
      o_search_pattern = context.search_pattern,
      o_search_pattern_history = context.search_pattern_history,
      o_replace_pattern = context.replace_pattern,
      o_replace_pattern_history = context.replace_pattern_history,
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

return search_in_buffer
