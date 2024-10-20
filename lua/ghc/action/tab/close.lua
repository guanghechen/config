---@class ghc.action.tab
local M = require("ghc.action.tab.mod")

---@return nil
function M.close_current()
  local tab_count = vim.fn.tabpagenr("$") ---@type integer
  if tab_count <= 1 then
    eve.reporter.warn({
      from = "fml.api.tab",
      subject = "close_current",
      message = "This is the last tab, cannot close it.",
    })
    return
  end

  local tabnr = vim.api.nvim_get_current_tabpage() ---@type integer
  eve.context.state.tabs[tabnr] = nil
  vim.cmd("tabclose")
end

---@param step                         integer
---@return nil
function M.close_left(step)
  step = math.max(1, step or vim.v.count1 or 1)
  local tabpages = vim.api.nvim_list_tabpages()
  local tabid_cur = vim.fn.tabpagenr() ---@type integer
  local tabid_next = eve.navigate.limit(tabid_cur, -step, #tabpages)

  for i = tabid_next, tabid_cur - 1, 1 do
    local tabnr = tabpages[i] ---@type integer
    eve.context.state.tabs[tabnr] = nil
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
  local tabid_next = eve.navigate.limit(tabid_cur, step, #tabpages)

  for i = tabid_cur + 1, tabid_next, 1 do
    local tabnr = tabpages[i] ---@type integer
    eve.context.state.tabs[tabnr] = nil
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

---@return nil
function M.close_others()
  local tabnr_cur = vim.api.nvim_get_current_tabpage() ---@type integer
  vim.cmd("tabonly")

  eve.object.filter_inline(eve.context.state.tabs, function(_, tabnr)
    return tabnr == tabnr_cur
  end)
  eve.context.state.tab_history:clear()
  eve.context.state.tab_history:push(tabnr_cur)
end
