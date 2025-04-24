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

----------------------------------------------------------------------------------------------------

---@param tabnr                         integer
---@param filetype                      string|nil
---@return integer|nil
function M.find_fixed(tabnr, filetype)
  local winnrs = vim.api.nvim_tabpage_list_wins(tabnr) ---@type integer[]
  for _, winnr in pairs(winnrs) do
    local bufnr = vim.api.nvim_win_get_buf(winnr) ---@type integer
    if (filetype == nil or vim.bo[bufnr].filetype == filetype) and M.is_fixed(winnr) then
      return winnr
    end
  end
  return nil
end

----------------------------------------------------------------------------------------------------

---@param winnr                         integer
---@return boolean
function M.is_fixed(winnr)
  local config = vim.api.nvim_win_get_config(winnr) ---@type vim.api.keyset.win_config
  return config == nil or config.relative == ""
end

---@param winnr                         integer
---@return boolean
function M.is_floating(winnr)
  local config = vim.api.nvim_win_get_config(winnr) ---@type vim.api.keyset.win_config
  return config.relative ~= nil and config.relative ~= ""
end

---@param winnr                         integer
---@return boolean
function M.is_valid(winnr)
  return winnr > 0 and vim.api.nvim_win_is_valid(winnr)
end

return M
