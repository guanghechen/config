---@class ghc.action.win
local M = {}

---@return nil
function M.scroll_down()
  local lines = vim.api.nvim_win_get_height(0) ---@type integer
  local half = math.floor(lines / 2) ---@type integer
  local keys = vim.api.nvim_replace_termcodes("" .. half .. "j", true, false, true) ---@type string
  vim.api.nvim_feedkeys(keys, "n", true)
end

---@return nil
function M.scroll_up()
  local lines = vim.api.nvim_win_get_height(0) ---@type integer
  local half = math.floor(lines / 2) ---@type integer
  local keys = vim.api.nvim_replace_termcodes("" .. half .. "k", true, false, true) ---@type string
  vim.api.nvim_feedkeys(keys, "n", true)
end

return M
