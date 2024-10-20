---@class ghc.action.win
local M = require("ghc.action.win.mod")

---@return nil
function M.split_horizontal()
  local winnr_cur = vim.api.nvim_get_current_win() ---@type integer

  vim.cmd("split")

  if not eve.win.is_floating(winnr_cur) then
    local winnr_new = vim.api.nvim_get_current_win() ---@type integer
    local win_cur = eve.context.state.wins[winnr_cur]
    if win_cur ~= nil then
      eve.context.state.wins[winnr_new] = {
        filepath_history = win_cur.filepath_history:fork({ name = "win_filepath" }),
        lsp_symbols = eve.array.slice(win_cur.lsp_symbols),
      }
    end
  end
end

---@return nil
function M.split_vertical()
  local winnr_cur = vim.api.nvim_get_current_win() ---@type integer

  vim.cmd("vsplit")

  if not eve.win.is_floating(winnr_cur) then
    local winnr_new = vim.api.nvim_get_current_win() ---@type integer
    local win_cur = eve.context.state.wins[winnr_cur]
    if win_cur ~= nil then
      eve.context.state.wins[winnr_new] = {
        filepath_history = win_cur.filepath_history:fork({ name = "win_filepath" }),
        lsp_symbols = eve.array.slice(win_cur.lsp_symbols),
      }
    end
  end
end
