local state = require("fml.api.state")
local navigate_limit = require("fml.fn.navigate_limit")
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

    if k == 0 then
      state.close_tab(tabnr)
    else
      state.refresh_tab(tabnr)
    end
  end

  state.remove_unrefereced_bufs(bufnrs)
end

---@return nil
function M.close_current()
  local tab = state.get_current_tab()
  if tab == nil then
    return
  end

  local bufnr_cur = vim.api.nvim_get_current_buf() ---@type integer
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
  local bufid_next = navigate_limit(bufid_cur, -step, #tab.bufnrs)
  local bufnrs_to_remove = std_array.slice(tab.bufnrs, bufid_next, bufid_cur - 1) ---@type integer[]
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
  local bufid_next = navigate_limit(bufid_cur, step, #tab.bufnrs)
  local bufnrs_to_remove = std_array.slice(tab.bufnrs, bufid_cur + 1, bufid_next)({}) ---@type integer[]
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
  local bufnrs_to_remove = std_array.filter(tab.bufnrs, function(bufnr)
    return bufnr ~= bufnr_cur
  end)
  M.close(bufnrs_to_remove)
end

---@return nil
function M.close_all()
  local tab = state.get_current_tab() ---@type fml.api.state.ITabItem|nil
  if tab == nil then
    return
  end

  local bufnrs_to_remove = std_array.slice(tab.bufnrs) ---@type integer[]
  M.close(bufnrs_to_remove)
end
