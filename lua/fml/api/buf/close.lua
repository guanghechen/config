local state = require("fml.api.state")
local navigate_limit = require("fml.fn.navigate_limit")
local std_array = require("fml.std.array")

---@class fml.api.buf
local M = require("fml.api.buf.mod")

---@return nil
function M.close_current()
  local bufnr_cur = vim.api.nvim_get_current_buf() ---@type integer
  local tab = state.get_current_tab()
  if tab == nil or not std_array.contains(tab.bufnrs, bufnr_cur) then
    state.schedule_refresh()
  end
  state.close_bufs({ bufnr_cur })
end

---@param step                          ?integer
---@return nil
function M.close_left(step)
  local tab, tabnr_cur = state.get_current_tab()
  if tab == nil then
    return
  end

  if #tab.bufnrs < 1 then
    state.tabs[tabnr_cur] = nil
    if vim.api.nvim_tabpage_is_valid(tabnr_cur) then
      vim.cmd("tabclose")
    end
    state.schedule_refresh()
    return
  end

  step = math.max(1, step or vim.v.count1 or 1)
  local bufnr_cur = vim.api.nvim_get_current_buf() ---@type integer
  local bufid_cur = std_array.first(tab.bufnrs, bufnr_cur) or 1 ---@type integer
  local bufid_next = navigate_limit(bufid_cur, -step, #tab.bufnrs)

  local bufnrs_to_remove = {} ---@type integer[]
  for i = bufid_next, bufid_cur - 1, 1 do
    table.insert(bufnrs_to_remove, tab.bufnrs[i])
  end
  state.close_bufs(bufnrs_to_remove)
end

---@param step                          ?integer
---@return nil
function M.close_right(step)
  local tab, tabnr_cur = state.get_current_tab()
  if tab == nil then
    return
  end

  if #tab.bufnrs < 1 then
    state.tabs[tabnr_cur] = nil
    if vim.api.nvim_tabpage_is_valid(tabnr_cur) then
      vim.cmd("tabclose")
    end
    state.schedule_refresh()
    return
  end

  step = math.max(1, step or vim.v.count1 or 1)
  local bufnr_cur = vim.api.nvim_get_current_buf() ---@type integer
  local bufid_cur = std_array.first(tab.bufnrs, bufnr_cur) or 1 ---@type integer
  local bufid_next = navigate_limit(bufid_cur, step, #tab.bufnrs)

  local bufnrs_to_remove = {} ---@type integer[]
  for i = bufid_cur + 1, bufid_next, 1 do
    table.insert(bufnrs_to_remove, tab.bufnrs[i])
  end
  state.close_bufs(bufnrs_to_remove)
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
  local bufnrs_to_remove = std_array.filter(tab.bufnrs, function(bufnr)
    return bufnr ~= bufnr_cur
  end)
  state.close_bufs(bufnrs_to_remove)
end

---@return nil
function M.close_all()
  local tab = state.get_current_tab() ---@type fml.api.state.ITabItem|nil
  if tab == nil then
    return
  end

  local bufnrs_to_remove = std_array.slice(tab.bufnrs) ---@type integer[]
  state.close_bufs(bufnrs_to_remove)
end
