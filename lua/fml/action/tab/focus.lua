---@param tabnr                         integer the stable unique number of the tabpage
---@return nil
local function go(tabnr)
  local tabnr_from = vim.api.nvim_get_current_tabpage() ---@type integer
  if tabnr_from ~= tabnr then
    vim.api.nvim_set_current_tabpage(tabnr)
  end
end

---@class fml.action.tab
local M = {}

---@param tabid                         integer the index of tab list
---@return nil
function M.focus(tabid)
  local tab_count = vim.fn.tabpagenr("$") ---@type integer
  local tabid_next = std.fn.navigate_limit(0, tabid, tab_count)
  local tabpages = vim.api.nvim_list_tabpages()
  local tabnr_next = tabpages[tabid_next]
  go(tabnr_next)
end

---@param step                          integer|nil
---@return nil
function M.focus_left(step)
  step = math.max(1, step or vim.v.count1 or 1)
  local tabid_cur = vim.fn.tabpagenr() ---@type integer
  local tab_count = vim.fn.tabpagenr("$") ---@type integer
  local tabid_next = std.fn.navigate_circular(tabid_cur, -step, tab_count)
  local tabpages = vim.api.nvim_list_tabpages()
  local tabnr_next = tabpages[tabid_next]
  go(tabnr_next)
end

---@param step                          integer|nil
---@return nil
function M.focus_right(step)
  step = math.max(1, step or vim.v.count1 or 1)
  local tabid_cur = vim.fn.tabpagenr() ---@type integer
  local tab_count = vim.fn.tabpagenr("$") ---@type integer
  local tabid_next = std.fn.navigate_circular(tabid_cur, step, tab_count)
  local tabpages = vim.api.nvim_list_tabpages()
  local tabnr_next = tabpages[tabid_next]
  go(tabnr_next)
end

return M
