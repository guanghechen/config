local constant = require("fml.constant")
local History = require("fml.collection.history")
local std_array = require("fml.std.array")
local std_object = require("fml.std.object")

---@param winnr number
---@return boolean
local function is_floating_win(winnr)
  local config = vim.api.nvim_win_get_config(winnr)
  return config.relative ~= nil and config.relative ~= ""
end

---@param winnr                         integer
---@return boolean
local function validate_win(winnr)
  if not vim.api.nvim_win_is_valid(winnr) then
    return false
  end
  return not is_floating_win(winnr)
end

---@class fml.api.state
---@field public wins                   table<integer, fml.api.state.IWinItem>
---@field public win_history            fml.types.collection.IHistory
---@field public is_floating_win        fun(winnr: integer): boolean
---@field public validate_win           fun(winnr: integer): boolean
local M = require("fml.api.state.mod")

M.wins = {}
M.win_history = History.new({
  name = "wins",
  capacity = constant.WIN_HISTORY_CAPACITY,
  validate = validate_win,
})
M.is_floating_win = is_floating_win
M.validate_win = validate_win

---@param winnr                         integer
---@return fun(bufnr: integer): boolean
function M.create_win_buf_history_validate(winnr)
  return function(bufnr)
    local win = M.wins[winnr]
    if win == nil then
      return false
    end

    local tab = M.tabs[win.tabnr]
    if tab == nil then
      return false
    end

    return vim.api.nvim_buf_is_valid(bufnr) and tab.bufnr_set[bufnr]
  end
end

---@param tabnr                         integer
---@return nil
function M.refresh_wins(tabnr)
  local winnrs = vim.api.nvim_tabpage_list_wins(tabnr) ---@type integer[]
  for _, winnr in ipairs(winnrs) do
    M.refresh_win(tabnr, winnr)
  end
  std_object.filter_inline(M.wins, function(win, winnr)
    return win.tabnr ~= tabnr or std_array.contains(winnrs, winnr)
  end)
end

---@param tabnr                         integer
---@param winnr                         integer
---@return nil
function M.refresh_win(tabnr, winnr)
  if not M.validate_win(winnr) then
    M.wins[winnr] = nil
    return
  end

  local win = M.wins[winnr] ---@type fml.api.state.IWinItem|nil
  if win == nil then
    ---@type fml.api.state.IWinItem
    win = {
      tabnr = tabnr,
      buf_history = History.new({
        name = "win#bufs",
        capacity = constant.WIN_BUF_HISTORY_CAPACITY,
        validate = M.create_win_buf_history_validate(winnr),
      }),
      lsp_symbols = {},
    }
    M.wins[winnr] = win
  end

  local bufnr = vim.api.nvim_win_get_buf(winnr)
  if bufnr ~= nil and win.buf_history:empty() then
    win.buf_history:push(bufnr)
  end
end
