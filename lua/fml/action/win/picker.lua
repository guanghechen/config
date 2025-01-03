local functional = require("eve.builtin.functional")
local fts = require("eve.constant.filetype")

local filters = {
  ---@param winnr                       integer
  ---@return boolean
  focus = function(winnr)
    local bufnr = vim.api.nvim_win_get_buf(winnr) ---@type integer
    local filetype = vim.bo[bufnr].filetype ---@type string
    return not fts.is_not_focusable_filetype(filetype)
  end,
  ---@param winnr                       integer
  ---@return boolean
  swap = function(winnr)
    if winnr == nil or winnr < 1 or not vim.api.nvim_win_is_valid(winnr) then
      return false
    end

    if functional.is_win_floating(winnr) then
      return false
    end

    local bufnr = vim.api.nvim_win_get_buf(winnr) ---@type integer
    local filetype = vim.bo[bufnr].filetype ---@type string
    return not fts.is_not_projectable_filetype(filetype)
  end,
  ---@param winnr                       integer
  ---@return boolean
  project = function(winnr)
    if winnr == nil or winnr < 1 or not vim.api.nvim_win_is_valid(winnr) then
      return false
    end

    if functional.is_win_floating(winnr) then
      return false
    end

    local bufnr = vim.api.nvim_win_get_buf(winnr) ---@type integer
    local filetype = vim.bo[bufnr].filetype ---@type string
    return not fts.is_not_projectable_filetype(filetype)
  end,
}

---@param filter                        fun(winnr: integer): boolean
---@param winnr_cur                     integer
---@return integer|nil
local function pick(filter, winnr_cur)
  local winpicker = require("eve.module.winpicker")
  return winpicker.pick_window(filter, winnr_cur)
end

---@class fml.action.win.picker
local M = {}

---@param context                       eve.command.IContext
---@return nil
function M.focus(context)
  local winnr_cur = context.winnr ---@type integer
  local winnr_target = pick(filters.focus, winnr_cur) ---@type integer|nil
  if winnr_target and winnr_cur ~= winnr_target then
    vim.api.nvim_set_current_win(winnr_target)
  end
end

---@param context                       eve.command.IContext
---@return nil
function M.project(context)
  local winnr_cur = context.winnr ---@type integer
  local winnr_target = pick(filters.project, winnr_cur) ---@type integer|nil
  if not winnr_target or winnr_cur == winnr_target then
    return
  end

  local bufnr_cur = context.bufnr ---@type integer
  local cursor_current = vim.api.nvim_win_get_cursor(winnr_cur)

  vim.api.nvim_win_set_buf(winnr_target, bufnr_cur)
  vim.api.nvim_win_set_cursor(winnr_target, cursor_current)
  vim.api.nvim_set_current_win(winnr_target)
end

---@param context                       eve.command.IContext
---@return nil
function M.swap(context)
  local winnr_cur = context.winnr ---@type integer
  local winnr_target = pick(filters.project, winnr_cur) ---@type integer|nil
  if not winnr_target or winnr_cur == winnr_target then
    return
  end

  local wincfg_current = vim.api.nvim_win_get_config(winnr_cur) ---@type vim.api.keyset.win_config
  local wincfg_target = vim.api.nvim_win_get_config(winnr_cur) ---@type vim.api.keyset.win_config
  vim.api.nvim_win_set_config(winnr_cur, wincfg_target)
  vim.api.nvim_win_set_config(winnr_target, wincfg_current)
end

return M
