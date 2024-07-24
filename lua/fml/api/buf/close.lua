local state = require("fml.api.state")
local navigate = require("fml.std.navigate")
local std_array = require("fml.std.array")
local std_set = require("fml.std.set")

---@class fml.api.buf
local M = require("fml.api.buf.mod")

---@param bufnrs                        integer[]
---@return nil
function M.close(bufnrs)
  if #bufnrs < 1 then
    return
  end

  local tabnr = vim.api.nvim_get_current_tabpage() ---@type integer
  local tab = state.tabs[tabnr] ---@type fml.api.state.ITabItem
  if tab ~= nil then
    local bufnr_set = std_set.from_integer_array(bufnrs) ---@type table<integer, boolean>
    local k = 0 ---@type integer
    local N = #tab.bufnrs ---@type integer
    for i = 1, N, 1 do
      local bufnr = tab.bufnrs[i]
      if not bufnr_set[bufnr] then
        k = k + 1
        tab.bufnrs[k] = bufnr
      else
        tab.bufnr_set[bufnr] = false
      end
    end
    for _ = k + 1, N, 1 do
      table.remove(tab.bufnrs)
    end
  end

  state.remove_unrefereced_bufs(bufnrs)
end

---@return nil
function M.close_current()
  local winnr = vim.api.nvim_get_current_win() ---@type integer
  local win = state.wins[winnr] ---@type fml.api.state.IWinItem|nil

  if win == nil then
    return
  end

  local bufnr_cur = vim.api.nvim_get_current_buf() ---@type integer

  ---! Set the buf to the last buf in the history before closing the current buf to avoid unexpected behaviors.
  local bufnr_last = win.buf_history:back() ---@type integer|nil
  if bufnr_last ~= nil and vim.api.nvim_buf_is_valid(bufnr_last) then
    vim.api.nvim_win_set_buf(winnr, bufnr_last)
  end

  M.close({ bufnr_cur })
end

---@param step                          ?integer
---@return nil
function M.close_left(step)
  local tab = state.get_current_tab()
  if tab == nil then
    return
  end

  step = math.max(1, step or vim.v.count1 or 1)
  local bufnr_cur = vim.api.nvim_get_current_buf() ---@type integer
  local bufid_cur = std_array.first(tab.bufnrs, bufnr_cur) or 1 ---@type integer
  local bufid_next = navigate.limit(bufid_cur, -step, #tab.bufnrs)
  local bufnrs_to_remove = {} ---@type integer[]
  for id = bufid_next, bufid_cur - 1, 1 do
    local nr = tab.bufnrs[id]
    local buf = state.bufs[nr]
    if buf == nil or not buf.pinned then
      table.insert(bufnrs_to_remove, nr)
    end
  end

  M.close(bufnrs_to_remove)
end

---@param step                          ?integer
---@return nil
function M.close_right(step)
  local tab = state.get_current_tab()
  if tab == nil then
    return
  end

  step = math.max(1, step or vim.v.count1 or 1)
  local bufnr_cur = vim.api.nvim_get_current_buf() ---@type integer
  local bufid_cur = std_array.first(tab.bufnrs, bufnr_cur) or 1 ---@type integer
  local bufid_next = navigate.limit(bufid_cur, step, #tab.bufnrs)
  local bufnrs_to_remove = {} ---@type integer[]
  for id = bufid_cur + 1, bufid_next, 1 do
    local nr = tab.bufnrs[id]
    local buf = state.bufs[nr]
    if buf == nil or not buf.pinned then
      table.insert(bufnrs_to_remove, nr)
    end
  end

  M.close(bufnrs_to_remove)
end

---@return nil
function M.close_to_leftest()
  M.close_left(math.huge)
end

---@return nil
function M.close_to_rightest()
  M.close_right(math.huge)
end

---@return nil
function M.close_others()
  local tab = state.get_current_tab() ---@type fml.api.state.ITabItem|nil
  if tab == nil then
    return
  end

  local bufnr_cur = vim.api.nvim_get_current_buf() ---@type integer
  local bufnrs_to_remove = {} ---@type integer[]
  for _, bufnr in ipairs(tab.bufnrs) do
    local buf = state.bufs[bufnr]
    if bufnr ~= bufnr_cur and (buf == nil or not buf.pinned) then
      table.insert(bufnrs_to_remove, bufnr)
    end
  end

  M.close(bufnrs_to_remove)
end

---@return nil
function M.close_all()
  local tab = state.get_current_tab() ---@type fml.api.state.ITabItem|nil
  if tab == nil then
    return
  end

  local bufnrs_to_remove = {} ---@type integer[]
  for _, bufnr in ipairs(tab.bufnrs) do
    local buf = state.bufs[bufnr]
    if buf == nil or not buf.pinned then
      table.insert(bufnrs_to_remove, bufnr)
    end
  end

  M.close(bufnrs_to_remove)
end
