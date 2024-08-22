local reporter = require("fml.std.reporter")
local state = require("fml.api.state")

---@class fml.api.win
local M = require("fml.api.win.mod")

---@return nil
function M.back()
  local winnr = vim.api.nvim_get_current_win() ---@type integer
  local win = state.wins[winnr]
  if win == nil then
    reporter.error({
      from = "fml.api.win",
      subject = "back",
      message = "Cannot find window.",
      details = { winnr = winnr },
    })
    return
  end

  local bufnr_cur = vim.api.nvim_get_current_buf() ---@type integer
  local bufnr_last = win.buf_history:back(1) ---@type integer
  if bufnr_cur ~= bufnr_last and bufnr_last ~= nil then
    vim.api.nvim_win_set_buf(winnr, bufnr_last)
  end
end

function M.forward()
  local winnr = vim.api.nvim_get_current_win() ---@type integer
  local win = state.wins[winnr]
  if win == nil then
    reporter.error({
      from = "fml.api.win",
      subject = "back",
      message = "Cannot find window.",
      details = { winnr = winnr },
    })
    return
  end

  local bufnr_cur = vim.api.nvim_get_current_buf() ---@type integer
  local bufnr_next = win.buf_history:forward(1) ---@type integer
  if bufnr_cur ~= bufnr_next and bufnr_next ~= nil then
    vim.api.nvim_win_set_buf(winnr, bufnr_next)
  end
end

function M.show_history()
  local winnr = vim.api.nvim_get_current_win()
  local win = state.wins[winnr]
  if win == nil then
    reporter.error({
      from = "fml.api.win",
      subject = "show_history",
      message = "Cannot find window.",
      details = { winnr = winnr },
    })
    return
  end
  win.buf_history:print()
end
