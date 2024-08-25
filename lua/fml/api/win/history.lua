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

  local last_filepath = win.filepath_history:back() ---@type string|nil
  if last_filepath ~= nil then
    state.open_filepath(winnr, last_filepath)
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

  local next_filepath = win.filepath_history:forward() ---@type string|nil
  if next_filepath ~= nil then
    state.open_filepath(winnr, next_filepath)
    return
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
  win.filepath_history:print()
end
