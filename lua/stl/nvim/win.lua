---@class stl.nvim.win
local M = {}

---@param winnr                         ?integer
---@return nil
function M.close(winnr)
  if winnr == nil or winnr < 1 or not vim.api.nvim_win_is_valid(winnr) then
    return
  end
  vim.api.nvim_win_close(winnr, true)
end

---@param tabnr                         integer
---@param filetype                      string
---@return integer|nil
function M.find_by_filetype(tabnr, filetype)
  local winnrs = vim.api.nvim_tabpage_list_wins(tabnr) ---@type integer[]
  for _, winnr in pairs(winnrs) do
    local bufnr = vim.api.nvim_win_get_buf(winnr) ---@type integer
    if vim.api.nvim_get_option_value("filetype", { buf = bufnr }) == filetype then
      return winnr
    end
  end
  return nil
end

---@param winnr                         integer
---@return boolean
function M.is_fixed(winnr)
  local config = vim.api.nvim_win_get_config(winnr) ---@type vim.api.keyset.win_config
  return config == nil or config.relative == ""
end

---@param winnr                         integer
---@return boolean
function M.is_float(winnr)
  local config = vim.api.nvim_win_get_config(winnr) ---@type vim.api.keyset.win_config
  return config.relative ~= nil and config.relative ~= ""
end

---@param winnr                         integer
---@return boolean
function M.is_valid(winnr)
  return winnr > 0 and vim.api.nvim_win_is_valid(winnr)
end

---@param winnr                         ?integer
---@return nil
function M.move_cursor_down(winnr)
  winnr = (winnr == nil or winnr == 0) and vim.api.nvim_get_current_win() or winnr ---@type integer
  if not vim.api.nvim_win_is_valid(winnr) then
    return
  end

  local bufnr = vim.api.nvim_win_get_buf(winnr) ---@type integer
  local total_lnum = math.max(vim.api.nvim_buf_line_count(bufnr), 1) ---@type integer
  local cursor = vim.api.nvim_win_get_cursor(winnr) ---@type integer[]
  local current_lnum = cursor[1] ---@type integer
  local next_lnum = math.min(total_lnum, math.max(1, current_lnum + vim.v.count1)) ---@type integer
  if next_lnum ~= current_lnum then
    vim.api.nvim_win_set_cursor(winnr, { next_lnum, 0 })
  end
end

---@param winnr                         ?integer
---@return nil
function M.move_cursor_last_line(winnr)
  winnr = (winnr == nil or winnr == 0) and vim.api.nvim_get_current_win() or winnr ---@type integer
  if not vim.api.nvim_win_is_valid(winnr) then
    return
  end

  local bufnr = vim.api.nvim_win_get_buf(winnr) ---@type integer
  local total_lnum = math.max(vim.api.nvim_buf_line_count(bufnr), 1) ---@type integer
  vim.api.nvim_win_set_cursor(winnr, { total_lnum, 0 })
end

---@param winnr                         ?integer
---@return nil
function M.move_cursor_to(winnr)
  winnr = (winnr == nil or winnr == 0) and vim.api.nvim_get_current_win() or winnr ---@type integer
  if not vim.api.nvim_win_is_valid(winnr) then
    return
  end

  local bufnr = vim.api.nvim_win_get_buf(winnr) ---@type integer
  local total_lnum = math.max(vim.api.nvim_buf_line_count(bufnr), 1) ---@type integer
  local target_lnum = vim.v.count > 0 and vim.v.count or 1 ---@type integer
  target_lnum = math.min(total_lnum, math.max(1, target_lnum))
  vim.api.nvim_win_set_cursor(winnr, { target_lnum, 0 })
end

---@param winnr                         ?integer
---@return nil
function M.move_cursor_up(winnr)
  winnr = (winnr == nil or winnr == 0) and vim.api.nvim_get_current_win() or winnr ---@type integer
  if not vim.api.nvim_win_is_valid(winnr) then
    return
  end

  local bufnr = vim.api.nvim_win_get_buf(winnr) ---@type integer
  local total_lnum = math.max(vim.api.nvim_buf_line_count(bufnr), 1) ---@type integer
  local cursor = vim.api.nvim_win_get_cursor(winnr) ---@type integer[]
  local current_lnum = cursor[1] ---@type integer
  local next_lnum = math.min(total_lnum, math.max(1, current_lnum - vim.v.count1)) ---@type integer
  if next_lnum ~= current_lnum then
    vim.api.nvim_win_set_cursor(winnr, { next_lnum, 0 })
  end
end

return M
