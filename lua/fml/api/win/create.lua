local state = require("fml.api.state")

---@class fml.api.win
local M = require("fml.api.win.mod")

---@return nil
function M.split_horizontal()
  local tabnr = vim.api.nvim_get_current_tabpage() ---@type integer
  local winnr_cur = vim.api.nvim_get_current_win() ---@type integer

  vim.cmd("split")

  local winnr_new = vim.api.nvim_get_current_win() ---@type integer
  local win_cur = state.wins[winnr_cur]
  if win_cur ~= nil then
    state.wins[winnr_new] = {
      tabnr = tabnr,
      buf_history = win_cur.buf_history:fork(),
    }
  else
    state.refresh_tab(tabnr)
  end
end

function M.split_vertical()
  local tabnr = vim.api.nvim_get_current_tabpage() ---@type integer
  local winnr_cur = vim.api.nvim_get_current_win() ---@type integer

  vim.cmd("vsplit")

  local winnr_new = vim.api.nvim_get_current_win() ---@type integer
  local win_cur = state.wins[winnr_cur]
  if win_cur ~= nil then
    state.wins[winnr_new] = {
      tabnr = tabnr,
      buf_history = win_cur.buf_history:fork(),
    }
  else
    state.refresh_tab(tabnr)
  end
end
