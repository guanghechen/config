---@class dot.fn.insert_splitline.SPLITLINE_BY_FILETYPE
local SPLITLINE_BY_FILETYPE = {
  lua = string.rep("-", 100),
  markdown = string.rep("-", 100),
}

---@return nil
local function insert_splitline()
  local winnr = vim.api.nvim_get_current_win() ---@type integer
  local bufnr = vim.api.nvim_win_get_buf(winnr) ---@type integer

  if vim.bo[bufnr].readonly or not vim.bo[bufnr].modifiable then
    local FEEDBACK_KEY = ark.var.K_CODE_INSERT_SPLITLINE ---@type string
    vim.api.nvim_feedkeys(vim.api.nvim_replace_termcodes(FEEDBACK_KEY, true, false, true), "n", false)
    return
  end

  local filetype = vim.bo[bufnr].filetype ---@type string
  local content = SPLITLINE_BY_FILETYPE[filetype] ---@type string|nil

  if content == nil then
    local FEEDBACK_KEY = ark.var.K_CODE_INSERT_SPLITLINE ---@type string
    vim.api.nvim_feedkeys(vim.api.nvim_replace_termcodes(FEEDBACK_KEY, true, false, true), "n", false)
    return
  end

  local cursor = vim.api.nvim_win_get_cursor(winnr)
  local row = cursor[1] ---@type integer
  vim.api.nvim_buf_set_lines(bufnr, row, row, false, { "", content, "" })
  vim.api.nvim_win_set_cursor(winnr, { row + 2, 0 })
end

return insert_splitline
