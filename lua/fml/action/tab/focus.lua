local fn = require("eve.builtin.fn")
local state = require("eve.state")

---@param tabnr                         integer the stable unique number of the tabpage
---@return nil
local function go(tabnr)
  local tabnr_from = vim.api.nvim_get_current_tabpage() ---@type integer
  if tabnr_from ~= tabnr then
    vim.api.nvim_set_current_tabpage(tabnr)
    state.tab.tab_history:push(tabnr)
  end
end

---@class fml.action.tab
local M = {}

---@param context                       eve.command.IContext
---@param tabid                         integer the index of tab list
---@return nil
---@diagnostic disable-next-line: unused-local
function M.focus(context, tabid)
  local tab_count = vim.fn.tabpagenr("$") ---@type integer
  local tabid_next = fn.navigate_limit(0, tabid, tab_count)
  local tabpages = vim.api.nvim_list_tabpages()
  local tabnr_next = tabpages[tabid_next]
  go(tabnr_next)
end

---@param context                       eve.command.IContext
---@param step                          integer|nil
---@return nil
---@diagnostic disable-next-line: unused-local
function M.focus_left(context, step)
  step = math.max(1, step or vim.v.count1 or 1)
  local tabid_cur = vim.fn.tabpagenr() ---@type integer
  local tab_count = vim.fn.tabpagenr("$") ---@type integer
  local tabid_next = fn.navigate_circular(tabid_cur, -step, tab_count)
  local tabpages = vim.api.nvim_list_tabpages()
  local tabnr_next = tabpages[tabid_next]
  go(tabnr_next)
end

---@param context                       eve.command.IContext
---@param step                          integer|nil
---@return nil
---@diagnostic disable-next-line: unused-local
function M.focus_right(context, step)
  step = math.max(1, step or vim.v.count1 or 1)
  local tabid_cur = vim.fn.tabpagenr() ---@type integer
  local tab_count = vim.fn.tabpagenr("$") ---@type integer
  local tabid_next = fn.navigate_circular(tabid_cur, step, tab_count)
  local tabpages = vim.api.nvim_list_tabpages()
  local tabnr_next = tabpages[tabid_next]
  go(tabnr_next)
end

return M
