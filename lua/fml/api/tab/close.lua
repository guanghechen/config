local state = require("fml.api.state")

---@class fml.api.tab
local M = require("fml.api.tab.mod")

---@return nil
function M.close()
  local tabnr_cur = vim.api.nvim_get_current_tabpage() ---@type integer
  state.tabs[tabnr_cur] = nil
  M.rearrange_history()

  vim.cmd("tabclose")
  local tabnr_last = M.internal_back() ---@type integer|nil
  if tabnr_last ~= nil then
    vim.api.nvim_set_current_tabpage(tabnr_last)
  end
end

---@param count                         integer
---@return nil
function M.close_left(count)
  local tabpages = vim.api.nvim_list_tabpages()
  local tabid_cur = vim.fn.tabpagenr() ---@type integer
  local step = math.min(count, tabid_cur - 1)
  for i = 1, step, 1 do
    local tabnr = tabpages[tabid_cur - i] ---@type integer
    state.tabs[tabnr] = nil
  end
  M.rearrange_history()

  for _ = 1, step, 1 do
    vim.cmd("-tabclose")
  end
end

---@param count                         integer
---@return nil
function M.close_right(count)
  local tabpages = vim.api.nvim_list_tabpages()
  local tabid_cur = vim.fn.tabpagenr() ---@type integer
  local tab_count = #tabpages ---@type integer
  local step = math.min(count, tab_count - tabid_cur)
  for i = 1, step, 1 do
    local tabnr = tabpages[tabid_cur + i] ---@type integer
    state.tabs[tabnr] = nil
  end
  M.rearrange_history()

  for _ = 1, step, 1 do
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
  local tabpages = vim.api.nvim_list_tabpages()
  local tabnr_cur = vim.api.nvim_get_current_tabpage() ---@type integer
  for _, tabnr in ipairs(tabpages) do
    if tabnr ~= tabnr_cur then
      state.tabs[tabnr] = nil
    end
  end
  state.tab_history:clear()
  state.tab_history:push(tabnr_cur)

  vim.cmd("tabonly")
end
