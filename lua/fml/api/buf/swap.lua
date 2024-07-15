local state = require("fml.api.state")
local navigate_limit = require("fml.fn.navigate_limit")
local std_array = require("fml.std.array")

---@class fml.api.buf
local M = require("fml.api.buf.mod")

---@param step                         ?integer
---@return nil
function M.swap_left(step)
  local tab = state.get_current_tab() ---@type fml.api.state.ITabItem|nil
  if tab == nil then
    return
  end

  step = math.max(1, step or vim.v.count1 or 1)
  local bufnr_cur = vim.api.nvim_get_current_buf() ---@type integer
  local bufid_cur = std_array.first(tab.bufnrs, bufnr_cur) ---@type integer|nil

  if bufid_cur ~= nil then
    local bufid_next = navigate_limit(bufid_cur, -step, #tab.bufnrs)
    if bufid_cur ~= bufid_next then
      local bufnr_next = tab.bufnrs[bufid_next]
      tab.bufnrs[bufid_next] = bufnr_cur
      tab.bufnrs[bufid_cur] = bufnr_next
      vim.cmd("redrawtabline")
    end
  end
end

---@param step                         ?integer
---@return nil
function M.swap_right(step)
  local tab = state.get_current_tab() ---@type fml.api.state.ITabItem|nil
  if tab == nil then
    return
  end

  step = math.max(1, step or vim.v.count1 or 1)
  local bufnr_cur = vim.api.nvim_get_current_buf() ---@type integer
  local bufid_cur = std_array.first(tab.bufnrs, bufnr_cur) ---@type integer|nil

  if bufid_cur ~= nil then
    local bufid_next = navigate_limit(bufid_cur, step, #tab.bufnrs)
    if bufid_cur ~= bufid_next then
      local bufnr_next = tab.bufnrs[bufid_next]
      tab.bufnrs[bufid_next] = bufnr_cur
      tab.bufnrs[bufid_cur] = bufnr_next
      vim.cmd("redrawtabline")
    end
  end
end
