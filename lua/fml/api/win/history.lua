local state = require("fml.api.state")

---@class fml.api.win
local M = require("fml.api.win.mod")

---@return nil
function M.backward()
  local winnr = vim.api.nvim_get_current_win() ---@type integer
  local bufnr = vim.api.nvim_win_get_buf(winnr) ---@type integer
  local buftype = vim.bo[bufnr].buftype ---@type string
  if buftype == eve.constants.BT_QUICKFIX then
    eve.qflist.backward()
    return
  end

  local win = state.wins[winnr]
  if win == nil then
    eve.reporter.error({
      from = "fml.api.win",
      subject = "back",
      message = "Cannot find window.",
      details = { winnr = winnr },
    })
    return
  end

  local last_filepath = win.filepath_history:backward() ---@type string|nil
  if last_filepath ~= nil then
    state.open_filepath(winnr, last_filepath)
  end
end

---@return nil
function M.forward()
  local winnr = vim.api.nvim_get_current_win() ---@type integer
  local bufnr = vim.api.nvim_win_get_buf(winnr) ---@type integer
  local buftype = vim.bo[bufnr].buftype ---@type string
  if buftype == eve.constants.BT_QUICKFIX then
    eve.qflist.forward()
    return
  end

  local win = state.wins[winnr]
  if win == nil then
    eve.reporter.error({
      from = "fml.api.win",
      subject = "back",
      message = "Cannot find window.",
      details = { winnr = winnr },
    })
    return
  end

  local next_filepath = win.filepath_history:forward() ---@type string|nil
  if next_filepath ~= nil then
    state.open_filepath(winnr, next_filepath)
    return
  end
end
