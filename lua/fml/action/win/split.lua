---@param winnr_source                  integer
---@return nil
local function fork(winnr_source)
  local meta_forked = eve.state.win.fork(winnr_source) ---@type eve.state.win.meta.state|nil
  if meta_forked ~= nil then
    local winnr_target = vim.api.nvim_get_current_win() ---@type integer
    eve.state.win.set(winnr_target, meta_forked)
  end
end

---@class fml.action.win
local M = {}

---@return nil
function M.split_above()
  local winnr = vim.api.nvim_get_current_win() ---@type integer
  if not eve.editor.is_win_floating(winnr) then
    vim.api.nvim_tabpage_set_win(0, winnr)
    vim.opt.splitbelow = false
    vim.cmd("split")
    vim.opt.splitbelow = true
    fork(winnr)
  end
end

---@return nil
function M.split_right()
  local winnr = vim.api.nvim_get_current_win() ---@type integer
  if not eve.editor.is_win_floating(winnr) then
    vim.api.nvim_tabpage_set_win(0, winnr)
    vim.opt.splitright = true
    vim.cmd("vsplit")
    fork(winnr)
  end
end

---@return nil
function M.split_below()
  local winnr = vim.api.nvim_get_current_win() ---@type integer
  if not eve.editor.is_win_floating(winnr) then
    vim.api.nvim_tabpage_set_win(0, winnr)
    vim.opt.splitbelow = true
    vim.cmd("split")
    fork(winnr)
  end
end

---@return nil
function M.split_left()
  local winnr = vim.api.nvim_get_current_win() ---@type integer
  if not eve.editor.is_win_floating(winnr) then
    vim.api.nvim_tabpage_set_win(0, winnr)
    vim.opt.splitright = false
    vim.cmd("vsplit")
    vim.opt.splitright = true
    fork(winnr)
  end
end

return M
