local constant = require("fml.constant")
local History = require("fml.collection.history")
local std_array = require("fml.std.array")
local std_object = require("fml.std.object")

---@param bufnrs                        integer[]
---@param history                       fml.types.collection.IHistory
---@param validate_buf                  fun(bufnr: integer): boolean
---@return nil
local function rearrange_buf_history(bufnrs, history, validate_buf)
  ---! Update bufnrs
  std_array.filter_inline(bufnrs, validate_buf)

  ---! Update buf history
  local reverse_list = {} ---@type integer[]
  local bufnr_set = {} ---@type table<integer, boolean>
  local prev_present_index = history:present_index() ---@type integer
  local next_present_index = 0 ---@type integer
  for element, idx in history:iterator() do
    table.insert(reverse_list, element)
    if prev_present_index == idx then
      next_present_index = #reverse_list
    end
  end

  next_present_index = #reverse_list - next_present_index + 1
  history:clear()
  for i = #bufnrs, 1, -1 do
    local bufnr = bufnrs[i]
    if not bufnr_set[bufnr] then
      history:push(bufnr)
      next_present_index = next_present_index + 1
    end
  end
  for i = #reverse_list, 1, -1 do
    history:push(reverse_list[i])
  end

  if next_present_index == 0 then
    local bufnr = bufnrs[1] or vim.api.nvim_list_bufs()[1] ---@type integer|nil
    if bufnr then
      history:push(bufnr)
    end
  else
    history:go(next_present_index)
  end
end

---@param winnr                         integer
---@return boolean
local function validate_win(winnr)
  if not vim.api.nvim_win_is_valid(winnr) then
    return false
  end

  local config = vim.api.nvim_win_get_config(winnr)
  return config.relative == nil or config.relative == ""
end



---@class fml.api.state
---@field public wins                   table<integer, fml.api.state.IWinItem>
---@field public win_history            fml.types.collection.IHistory
---@field public validate_win           fun(winnr: integer): boolean
local M = require("fml.api.state.mod")

M.wins = {}
M.win_history = History.new({
  name = "wins",
  capacity = constant.WIN_HISTORY_CAPACITY,
  validate = validate_win,
})
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

    return vim.api.nvim_buf_is_valid(bufnr) and std_array.contains(tab.bufnrs, bufnr)
  end
end

---@param tabnr                         integer
---@return nil
function M.refresh_wins(tabnr)
  local winnrs = vim.api.nvim_tabpage_list_wins(tabnr) ---@type integer[]
  std_object.filter_inline(M.wins, function(win, winnr)
    if not vim.api.nvim_win_is_valid(winnr) then
      return false
    end
    return win.tabnr ~= tabnr or std_array.contains(winnrs, winnr)
  end)
  for _, winnr in ipairs(winnrs) do
    M.refresh_win(tabnr, winnr)
  end
end

---@param tabnr                         integer
---@param winnr                         integer
---@return nil
function M.refresh_win(tabnr, winnr)
  if winnr == nil or type(winnr) ~= "number" then
    return
  end

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
    }
    M.wins[winnr] = win
  end

  local bufnr = vim.api.nvim_win_get_buf(winnr)
  if bufnr ~= nil then
    win.buf_history:push(bufnr)
  end

  local bufnrs = vim.api.nvim_tabpage_list_wins(tabnr) ---@type integer[]
  rearrange_buf_history(bufnrs, win.buf_history, M.validate_buf)
end
