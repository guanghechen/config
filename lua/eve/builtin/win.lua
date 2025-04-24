---@alias eve.builtin.win.Wintype
---| "ux-board"
---| "ux-cmdline"
---| "ux-input"
---| "ux-maximize"
---| "ux-notify"
---| "ux-popupmenu"
---| "ux-search-input"
---| "ux-search-main"
---| "ux-search-preview"
---| "ux-select-popup"
---| "ux-terminal"
---| "ux-textarea"
---| "ux-winpicker"
---| "ux-winsep"

---@class eve.builtin.win
local M = {}

---@param winnr                         integer
---@param wintype                       eve.builtin.win.Wintype
---@return nil
function M.set_wintype(winnr, wintype)
  vim.w[winnr].eve_wintype = wintype
end

---@return eve.builtin.win.Wintype
function M.get_wintype(winnr)
  return vim.w[winnr].eve_wintype
end

---@param winnr                         integer
---@return boolean
function M.is_valid(winnr)
  return winnr > 0 and vim.api.nvim_win_is_valid(winnr)
end

return M
