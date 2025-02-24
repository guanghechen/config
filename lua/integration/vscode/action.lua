---@class integration.vscode.action
local M = {}

---@return nil
function M.goto_indent_scope_top()
  local cursor = vim.api.nvim_win_get_cursor(0)
  local lnum_cur = cursor[1] ---@type integer
  local line_cur = vim.fn.getline(lnum_cur) ---@type string
  local fnbc = string.find(line_cur, "%S") ---@type integer|nil
  local col_cur = (fnbc == nil or fnbc < cursor[2] + 1) and fnbc or cursor[2] + 1 ---@type integer

  for lnum = lnum_cur - 1, 1, -1 do
    local line = vim.fn.getline(lnum) ---@type string
    local col = string.find(line, "%S") ---@type integer|nil
    if col ~= nil and col <= col_cur then
      vim.api.nvim_win_set_cursor(0, { lnum, col - 1 })
      return
    end
  end

  vim.api.nvim_win_set_cursor(0, { 1, 0 })
end

---@return nil
function M.goto_indent_scope_bot()
  local N = vim.api.nvim_buf_line_count(0) ---@type integer
  local cursor = vim.api.nvim_win_get_cursor(0)
  local lnum_cur = cursor[1] ---@type integer
  local line_cur = vim.fn.getline(lnum_cur) ---@type string
  local fnbc = string.find(line_cur, "%S") ---@type integer|nil
  local col_cur = (fnbc == nil or fnbc <= cursor[2] + 1) and fnbc or cursor[2] + 1 ---@type integer

  for lnum = lnum_cur + 1, N, 1 do
    local line = vim.fn.getline(lnum) ---@type string
    local col = string.find(line, "%S") ---@type integer|nil
    if col ~= nil and col <= col_cur then
      vim.api.nvim_win_set_cursor(0, { lnum, col - 1 })
      return
    end
  end

  vim.api.nvim_win_set_cursor(0, { N, 0 })
end

return M
