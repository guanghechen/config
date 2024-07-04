local state = require("fml.api.state")

---@class fml.api.win
local M = require("fml.api.win.mod")

---@return nil
function M.split_horizontal()
  local tab = state.get_current_tab() ---@type fml.api.state.ITabItem|nil
  if tab == nil then
    return
  end

  local winnr_cur = vim.api.nvim_get_current_win() ---@type integer
  vim.cmd("split")
  local winnr_new = vim.api.nvim_get_current_win() ---@type integer

  local win = tab.wins[winnr_cur]
  if win ~= nil then
    tab.wins[winnr_new] = {
      buf_history = win.buf_history:clone(),
    }
  end
end

function M.split_vertical()
  local tab = state.get_current_tab() ---@type fml.api.state.ITabItem|nil
  if tab == nil then
    return
  end

  local winnr_cur = vim.api.nvim_get_current_win() ---@type integer
  vim.cmd("vsplit")
  local winnr_new = vim.api.nvim_get_current_win() ---@type integer

  local win = tab.wins[winnr_cur]
  if win ~= nil then
    tab.wins[winnr_new] = {
      buf_history = win.buf_history:clone(),
    }
  end
end
