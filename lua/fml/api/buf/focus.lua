local state = require("fml.api.state")
local navigate_circular = require("fml.fn.navigate_circular")
local reporter = require("fml.std.reporter")
local std_array = require("fml.std.array")

---@class fml.api.buf
---@field public focus_1                fun(): nil
---@field public focus_2                fun(): nil
---@field public focus_3                fun(): nil
---@field public focus_4                fun(): nil
---@field public focus_5                fun(): nil
---@field public focus_6                fun(): nil
---@field public focus_7                fun(): nil
---@field public focus_8                fun(): nil
---@field public focus_9                fun(): nil
---@field public focus_10               fun(): nil
local M = require("fml.api.buf.mod")

---@param bufnr                         integer the stable unique number of the buffer
---@return nil
function M.go(bufnr)
  local bufnr_from = vim.api.nvim_get_current_buf() ---@type integer
  if bufnr_from == bufnr then
    return
  end

  local winnr = vim.api.nvim_get_current_win() ---@type integer
  vim.api.nvim_win_set_buf(winnr, bufnr)

  local win = state.wins[winnr] ---@type fml.api.state.IWinItem|nil
  if win == nil then
    reporter.error({
      from = "fml.api.buf",
      subject = "focus.go",
      message = "Cannot find win from the state",
      details = {
        winnr = winnr,
        bufnr = bufnr,
      },
    })
    return
  end
  win.buf_history:push(bufnr)
end

---@param bufid                         integer the index of buffer list
---@return nil
function M.focus(bufid)
  local tab = state.get_current_tab() ---@type fml.api.state.ITabItem|nil
  if tab == nil then
    return
  end

  local bufid_next = navigate_circular(0, bufid, #tab.bufnrs)
  local bufnr_next = tab.bufnrs[bufid_next]
  M.go(bufnr_next)
end

---@param step                         ?integer
---@return nil
function M.focus_left(step)
  local tab = state.get_current_tab() ---@type fml.api.state.ITabItem|nil
  if tab == nil then
    return
  end

  step = math.max(1, step or vim.v.count1 or 1)
  local bufnr_cur = vim.api.nvim_get_current_buf() ---@type integer
  local bufid_cur = std_array.first(tab.bufnrs, bufnr_cur) or 1 ---@type integer
  local bufid_next = navigate_circular(bufid_cur, -step, #tab.bufnrs)
  local bufnr_next = tab.bufnrs[bufid_next]
  M.go(bufnr_next)
end

---@param step                         ?integer
---@return nil
function M.focus_right(step)
  local tab = state.get_current_tab() ---@type fml.api.state.ITabItem|nil
  if tab == nil then
    return
  end

  step = math.max(1, step or vim.v.count1 or 1)
  local bufnr = vim.api.nvim_get_current_buf() ---@type integer
  local bufid_cur = std_array.first(tab.bufnrs, bufnr) or 1 ---@type integer
  local bufid_next = navigate_circular(bufid_cur, step, #tab.bufnrs)
  local bufnr_next = tab.bufnrs[bufid_next]
  M.go(bufnr_next)
end

for i = 1, 10 do
  M["focus_" .. i] = function()
    M.focus(i)
  end
end
