---@class fml.action.win
local M = {}

---@return nil
function M.split_above()
  local winnr_source = vim.api.nvim_get_current_win() ---@type integer
  if not eve.win.is_floating(winnr_source) then
    vim.api.nvim_tabpage_set_win(0, winnr_source)
    vim.o.splitbelow = false
    vim.cmd("split")
    vim.o.splitbelow = true

    local winnr_target = vim.api.nvim_get_current_win() ---@type integer
    eve.win.fork(winnr_source, winnr_target)
  end
end

---@return nil
function M.split_right()
  local winnr_source = vim.api.nvim_get_current_win() ---@type integer
  if not eve.win.is_floating(winnr_source) then
    vim.api.nvim_tabpage_set_win(0, winnr_source)
    vim.o.splitright = true
    vim.cmd("vsplit")

    local winnr_target = vim.api.nvim_get_current_win() ---@type integer
    eve.win.fork(winnr_source, winnr_target)
  end
end

---@return nil
function M.split_below()
  local winnr_source = vim.api.nvim_get_current_win() ---@type integer
  if not eve.win.is_floating(winnr_source) then
    vim.api.nvim_tabpage_set_win(0, winnr_source)
    vim.o.splitbelow = true
    vim.cmd("split")

    local winnr_target = vim.api.nvim_get_current_win() ---@type integer
    eve.win.fork(winnr_source, winnr_target)
  end
end

---@return nil
function M.split_left()
  local winnr_source = vim.api.nvim_get_current_win() ---@type integer
  if not eve.win.is_floating(winnr_source) then
    vim.api.nvim_tabpage_set_win(0, winnr_source)
    vim.o.splitright = false
    vim.cmd("vsplit")
    vim.o.splitright = true

    local winnr_target = vim.api.nvim_get_current_win() ---@type integer
    eve.win.fork(winnr_source, winnr_target)
  end
end

return M
