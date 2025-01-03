local setting = require("eve.constant.setting")

---@class eve.lib.nvim
local M = {}

---@param filename                      string
---@return string
---@return string
function M.calc_fileicon(filename)
  local name = (not filename or filename == "") and setting.BUF_UNTITLED or filename
  local icons_present, icons = pcall(require, "mini.icons")
  if icons_present and name ~= setting.BUF_UNTITLED then
    local icon, icon_hl, is_default = icons.get("file", filename)
    if not is_default then
      return icon, icon_hl
    end
  end
  return "󰈚", "MiniIconsRed"
end

---@param winnr                         integer|nil
---@param width                         integer|nil
---@return nil
function M.dressing_float_win(winnr, width)
  if winnr == nil or winnr < 1 or not vim.api.nvim_win_is_valid(winnr) then
    return
  end

  width = width or 100

  local bufnr = vim.api.nvim_win_get_buf(winnr) ---@type integer
  local lines = vim.api.nvim_buf_get_lines(bufnr, 0, -1, false) ---@type string[]
  local wrap_count = 0 ---@type integer
  for _, line in ipairs(lines) do
    wrap_count = wrap_count + math.ceil(#line / width)
  end

  local state = require("eve.state")
  local winblend = state.theme.transparency:snapshot() and 0 or 10 ---@type integer

  vim.wo[winnr].number = false
  vim.wo[winnr].relativenumber = false
  vim.wo[winnr].signcolumn = "yes"
  vim.wo[winnr].winblend = winblend
  vim.wo[winnr].wrap = true
  vim.api.nvim_win_set_width(winnr, width)
  vim.api.nvim_win_set_height(winnr, math.min(40, math.max(2, wrap_count)))
  vim.api.nvim_set_current_win(winnr)
end

return M
