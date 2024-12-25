---@class fml.action.win
local M = {}

---@param context                       eve.command.IContext
---@return nil
function M.scroll_down(context)
  local winnr = context.winnr ---@type integer
  local lines = vim.api.nvim_win_get_height(winnr) ---@type integer
  local half = math.floor(lines / 2) ---@type integer
  local keys = vim.api.nvim_replace_termcodes("" .. half .. "j", true, false, true) ---@type string
  vim.api.nvim_feedkeys(keys, "n", true)
end

---@param context                       eve.command.IContext
---@return nil
function M.scroll_up(context)
  local winnr = context.winnr ---@type integer
  local lines = vim.api.nvim_win_get_height(winnr) ---@type integer
  local half = math.floor(lines / 2) ---@type integer
  local keys = vim.api.nvim_replace_termcodes("" .. half .. "k", true, false, true) ---@type string
  vim.api.nvim_feedkeys(keys, "n", true)
end

return M
