---@diagnostic disable: invisible
local __module_name__ = "fml.action.search.buffer" ---@type string

-- Module-level searcher instance
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

  local bufnr_sourcefile = vim.api.nvim_win_get_buf(winnr_sourcefile) ---@type integer
  if not vim.api.nvim_buf_is_valid(bufnr_sourcefile) then
    std.reporter.warn({
      from = __module_name__,
      message = "Invalid buffer for search",
    })
    return
  end

  -- Create or reuse searcher instance
  local popup_not_opened_yet = searcher == nil ---@type boolean
  if searcher == nil then
    searcher = eve.ux.searcher.BufferSearcher.new()
  end

  if searcher._bufnr_source ~= bufnr_sourcefile then
    searcher:clear_highlight()
    searcher._scheduler_search:schedule()
  end

  -- Initialize state for the search operation
  searcher._winnr_source = winnr_sourcefile
  searcher._bufnr_source = bufnr_sourcefile
  searcher._matches = {}

  -- If popup not opened yet and in visual mode, use selected text
  if popup_not_opened_yet then
    local mode = vim.fn.mode() ---@type string
    if mode == "v" or mode == "V" or mode == "\22" then -- visual, visual-line, visual-block
      local selected_text = eve.buf.retrieve_selected_text() ---@type string|nil
      if selected_text ~= nil and selected_text ~= "" then
        searcher.o_search_pattern:next(selected_text)
      end
    end
  end

  -- Create popup buffer and window
  local popup_winnr = searcher:create_popup_window_as_needed()
  searcher._nvimbar:render()

  -- Focus the popup and enter insert mode
  vim.api.nvim_set_current_win(popup_winnr)
  vim.cmd("startinsert!")
end

return M
