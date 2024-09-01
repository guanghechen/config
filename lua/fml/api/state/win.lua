local constant = require("fml.constant")
local AdvanceHistory = require("fc.collection.history_advance")
local reporter = require("fc.std.reporter")

---@class fml.api.state
local M = require("fml.api.state.mod")

---@param winnr                         integer
---@return fml.types.api.state.IWinItem|nil
function M.get_win(winnr)
  if M.wins[winnr] == nil then
    M.refresh_win(winnr)
  end

  local win = M.wins[winnr] ---@type fml.types.api.state.IWinItem|nil
  if win == nil then
    reporter.error({
      from = "fml.api.state",
      subject = "get_win",
      message = "Cannot find win from the state",
      details = { winnr = winnr },
    })
  end
  return win
end

---@param tabnr                         integer
---@return nil
function M.refresh_tabpage_wins(tabnr)
  local winnrs = vim.api.nvim_tabpage_list_wins(tabnr) ---@type integer[]
  for _, winnr in ipairs(winnrs) do
    M.refresh_win(winnr)
  end
end

---@return nil
function M.refresh_wins()
  local winnrs = vim.api.nvim_list_wins() ---@type integer[]
  local wins = {} ---@type table<integer, fml.types.api.state.IWinItem>
  for _, winnr in ipairs(winnrs) do
    local win = M.refresh_win(winnr) ---@type fml.types.api.state.IWinItem|nil
    if win ~= nil then
      wins[winnr] = win
    end
  end

  M.wins = wins
end

---@param winnr                         integer|nil
---@return fml.types.api.state.IWinItem|nil
function M.refresh_win(winnr)
  if winnr == nil or type(winnr) ~= "number" then
    return
  end

  if not M.validate_win(winnr) then
    M.wins[winnr] = nil
    return
  end

  local win = M.wins[winnr] ---@type fml.types.api.state.IWinItem|nil
  if win == nil then
    local bufnr = vim.api.nvim_win_get_buf(winnr) ---@type integer
    local filepath = vim.api.nvim_buf_get_name(bufnr) ---@type string
    local filepath_history = AdvanceHistory.new({
      name = "win#bufs",
      capacity = constant.WIN_BUF_HISTORY_CAPACITY,
      validate = M.validate_filepath,
    })
    filepath_history:push(filepath)

    ---@type fml.types.api.state.IWinItem
    win = { filepath_history = filepath_history, lsp_symbols = {} }
    M.wins[winnr] = win
  end
  return win
end
