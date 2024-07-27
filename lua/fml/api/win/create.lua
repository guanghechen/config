local state = require("fml.api.state")
local std_array = require("fml.std.array")

---@class fml.api.win
local M = require("fml.api.win.mod")

---@return nil
function M.split_horizontal()
  local winnr_cur = vim.api.nvim_get_current_win() ---@type integer

  vim.cmd("split")

  if not state.is_floating_win(winnr_cur) then
    local winnr_new = vim.api.nvim_get_current_win() ---@type integer
    local win_cur = state.wins[winnr_cur]
    if win_cur ~= nil then
      state.wins[winnr_new] = {
        buf_history = win_cur.buf_history:fork(),
        lsp_symbols = std_array.slice(win_cur.lsp_symbols),
      }
    end
  end
end

---@return nil
function M.split_vertical()
  local winnr_cur = vim.api.nvim_get_current_win() ---@type integer

  vim.cmd("vsplit")

  if not state.is_floating_win(winnr_cur) then
    local winnr_new = vim.api.nvim_get_current_win() ---@type integer
    local win_cur = state.wins[winnr_cur]
    if win_cur ~= nil then
      state.wins[winnr_new] = {
        buf_history = win_cur.buf_history:fork(),
        lsp_symbols = std_array.slice(win_cur.lsp_symbols),
      }
    end
  end
end
