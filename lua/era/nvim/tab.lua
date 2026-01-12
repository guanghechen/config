---@diagnostic disable-next-line: unused-local
local __module_name__ = "era.nvim.tab" ---@type string

---@class era.nvim.tab
local M = {}

----------------------------------------------------------------------------------------------------
-- close
----------------------------------------------------------------------------------------------------

---@return nil
function M.close()
  local N = vim.fn.tabpagenr("$") ---@type integer
  if N <= 1 then
    stl.reporter.warn({
      from = __module_name__,
      subject = "close",
      message = "This is the last tab, cannot close it.",
    })
    return
  end
  vim.cmd("tabclose")
end

---@return nil
function M.close_others()
  vim.cmd("tabonly")
end

---@return nil
function M.close_to_leftest()
  local tabid = vim.fn.tabpagenr() ---@type integer
  for _ = 1, tabid - 1, 1 do
    vim.cmd("-tabclose")
  end
end

---@return nil
function M.close_to_rightest()
  local N = vim.fn.tabpagenr("$") ---@type integer
  local tabid = vim.fn.tabpagenr() ---@type integer
  for _ = tabid + 1, N, 1 do
    vim.cmd("+tabclose")
  end
end

----------------------------------------------------------------------------------------------------
-- focus
----------------------------------------------------------------------------------------------------

---@param tabnr                         integer the stable unique number of the tabpage
---@return nil
local function __go__(tabnr)
  local tabnr_from = vim.api.nvim_get_current_tabpage() ---@type integer
  if tabnr_from ~= tabnr then
    vim.api.nvim_set_current_tabpage(tabnr)
  end
end

---@param tabid                         integer the index of tab list
---@return nil
function M.focus(tabid)
  local tab_count = vim.fn.tabpagenr("$") ---@type integer
  local tabid_next = stl.fn.navigate_limit(0, tabid, tab_count)
  local tabpages = vim.api.nvim_list_tabpages()
  local tabnr_next = tabpages[tabid_next]
  __go__(tabnr_next)
end

---@param step                          integer|nil
---@return nil
function M.focus_left(step)
  step = math.max(1, step or vim.v.count1 or 1)
  local tabid_cur = vim.fn.tabpagenr() ---@type integer
  local tab_count = vim.fn.tabpagenr("$") ---@type integer
  local tabid_next = stl.fn.navigate_circular(tabid_cur, -step, tab_count)
  local tabpages = vim.api.nvim_list_tabpages()
  local tabnr_next = tabpages[tabid_next]
  __go__(tabnr_next)
end

---@param step                          integer|nil
---@return nil
function M.focus_right(step)
  step = math.max(1, step or vim.v.count1 or 1)
  local tabid_cur = vim.fn.tabpagenr() ---@type integer
  local tab_count = vim.fn.tabpagenr("$") ---@type integer
  local tabid_next = stl.fn.navigate_circular(tabid_cur, step, tab_count)
  local tabpages = vim.api.nvim_list_tabpages()
  local tabnr_next = tabpages[tabid_next]
  __go__(tabnr_next)
end

----------------------------------------------------------------------------------------------------
-- new
----------------------------------------------------------------------------------------------------

---@return integer
function M.new()
  vim.cmd("$tabnew")
  vim.api.nvim_set_option_value("buflisted", false, { buf = 0 })
  vim.api.nvim_set_option_value("bufhidden", "wipe", { buf = 0 })

  local tabnr = vim.api.nvim_get_current_tabpage() ---@type integer
  dot.tab.set_type(tabnr, stl.nvim.tab.Types.NORMAL)
  dot.tab.resolve(tabnr, false)
  return tabnr
end

---@return integer
function M.new_with_buf()
  local bufnr = vim.api.nvim_get_current_buf() ---@type integer

  vim.cmd("$tabnew")
  vim.api.nvim_set_option_value("buflisted", false, { buf = 0 })
  vim.api.nvim_set_option_value("bufhidden", "wipe", { buf = 0 })

  local tabnr = vim.api.nvim_get_current_tabpage() ---@type integer
  dot.tab.set_type(tabnr, stl.nvim.tab.Types.NORMAL)

  local winnr = vim.api.nvim_tabpage_get_win(tabnr) ---@type integer
  vim.api.nvim_win_set_buf(winnr, bufnr)
  if vim.api.nvim_get_option_value("buflisted", { buf = bufnr }) then
    dot.tab.add_buf(tabnr, bufnr, false)
  end

  dot.tab.resolve(tabnr, false)
  return tabnr
end

return M
