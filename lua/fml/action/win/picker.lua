local winpicker = require("eve.module.winpicker")

---@class fml.action.win.picker
local M = {}

---@param context                       eve.command.IContext
---@return nil
function M.focus(context)
  local winnr_source = context.winnr
  local winnr_target = winpicker.pick_window(winpicker.filters.focus, winnr_source) ---@type integer|nil
  if winnr_target and winnr_target ~= winnr_source then
    vim.api.nvim_set_current_win(winnr_target)
  end
end

---@param context                       eve.command.IContext
---@return nil
function M.project(context)
  local winnr_source = context.winnr
  local winnr_target = winpicker.pick_window(winpicker.filters.project, winnr_source) ---@type integer|nil
  if winnr_target and winnr_target ~= winnr_source then
    local cursor_source = vim.api.nvim_win_get_cursor(winnr_source)
    local bufnr = context.bufnr ---@type integer

    vim.api.nvim_win_set_buf(winnr_target, bufnr)
    vim.api.nvim_win_set_cursor(winnr_target, cursor_source)
    vim.api.nvim_set_current_win(winnr_target)
  end
end

---@param context                       eve.command.IContext
---@return nil
function M.swap(context)
  local winnr_source = context.winnr
  local winnr_target = winpicker.pick_window(winpicker.filters.project, winnr_source) ---@type integer|nil
  if winnr_target and winnr_target ~= winnr_source then
    local wincfg_source = vim.api.nvim_win_get_config(winnr_source) ---@type vim.api.keyset.win_config
    local wincfg_target = vim.api.nvim_win_get_config(winnr_target) ---@type vim.api.keyset.win_config

    vim.api.nvim_win_set_config(winnr_source, wincfg_target)
    vim.api.nvim_win_set_config(winnr_target, wincfg_source)
  end
end

return M
