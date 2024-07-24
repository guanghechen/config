local state = require("fml.api.state")
local navigate = require("fml.std.navigate")
local std_object = require("fml.std.object")
local reporter = require("fml.std.reporter")

---@class fml.api.tab
local M = require("fml.api.tab.mod")

---@return nil
function M.close_current()
  local tab_count = vim.fn.tabpagenr("$") ---@type integer
  if tab_count <= 1 then
    reporter.info({
      from = "fml.api.tab",
      subject = "close_current",
      message = "This is the last tab, cannot close it.",
    })
    return
  end

  local tabnr = vim.api.nvim_get_current_tabpage() ---@type integer
  state.close_tab(tabnr)
end

---@param step                         integer
---@return nil
function M.close_left(step)
  step = math.max(1, step or vim.v.count1 or 1)
  local tabpages = vim.api.nvim_list_tabpages()
  local tabid_cur = vim.fn.tabpagenr() ---@type integer
  local tabid_next = navigate.limit(tabid_cur, -step, #tabpages)

  for i = tabid_next, tabid_cur - 1, 1 do
    local tabnr = tabpages[i] ---@type integer
    state.tabs[tabnr] = nil
  end
  for _ = tabid_next, tabid_cur - 1, 1 do
    vim.cmd("-tabclose")
  end
end

---@param step                         integer
---@return nil
function M.close_right(step)
  step = math.max(1, step or vim.v.count1 or 1)
  local tabpages = vim.api.nvim_list_tabpages()
  local tabid_cur = vim.fn.tabpagenr() ---@type integer
  local tabid_next = navigate.limit(tabid_cur, step, #tabpages)

  for i = tabid_cur + 1, tabid_next, 1 do
    local tabnr = tabpages[i] ---@type integer
    state.tabs[tabnr] = nil
  end
  for _ = tabid_cur + 1, tabid_next, 1 do
    vim.cmd("+tabclose")
  end
end

---@return nil
function M.close_to_leftest()
  M.close_left(math.huge)
end

---@return nil
function M.close_to_rightest()
  M.close_right(math.huge)
end

function M.close_others()
  local tabnr_cur = vim.api.nvim_get_current_tabpage() ---@type integer
  std_object.filter_inline(state.tabs, function(_, tabnr)
    return tabnr == tabnr_cur
  end)
  state.tab_history:clear()
  state.tab_history:push(tabnr_cur)

  vim.cmd("tabonly")
end
