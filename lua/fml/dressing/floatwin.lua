---@param winnr                         integer|nil
---@param width                         integer|nil
---@return nil
local function dressing_float_win(winnr, width)
  if winnr == nil or not eve.editor.is_win_valid(winnr) then
    return
  end

  width = width or 100

  local bufnr = vim.api.nvim_win_get_buf(winnr) ---@type integer
  local lines = vim.api.nvim_buf_get_lines(bufnr, 0, -1, false) ---@type string[]
  local wrap_count = 0 ---@type integer
  for _, line in ipairs(lines) do
    wrap_count = wrap_count + math.ceil(#line / width)
  end

  local winblend = eve.state.theme.transparency:snapshot() and 0 or 10 ---@type integer

  vim.wo[winnr].number = false
  vim.wo[winnr].relativenumber = false
  vim.wo[winnr].signcolumn = "yes"
  vim.wo[winnr].winblend = winblend
  vim.wo[winnr].wrap = true
  vim.api.nvim_win_set_width(winnr, width)
  vim.api.nvim_win_set_height(winnr, math.min(40, math.max(2, wrap_count)))
  vim.api.nvim_set_current_win(winnr)
end

return dressing_float_win
