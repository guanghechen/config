---@class ghc.command.scroll
local M = {}

---@return nil
function M.down_half_window()
  local lines = vim.api.nvim_win_get_height(0) ---@type integer
  local half = math.floor(lines / 2) ---@type integer
  local keys = vim.api.nvim_replace_termcodes("" .. half .. "j", true, false, true) ---@type string
  vim.api.nvim_feedkeys(keys, "n", true)
end

---@return nil
function M.up_half_window()
  local lines = vim.api.nvim_win_get_height(0) ---@type integer
  local half = math.floor(lines / 2) ---@type integer
  local keys = vim.api.nvim_replace_termcodes("" .. half .. "k", true, false, true) ---@type string
  vim.api.nvim_feedkeys(keys, "n", true)
end

return M
