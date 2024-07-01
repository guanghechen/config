---@class fml.api.tab
---@field public open1              fun(): nil
---@field public open2              fun(): nil
---@field public open3              fun(): nil
---@field public open4              fun(): nil
---@field public open5              fun(): nil
---@field public open6              fun(): nil
---@field public open7              fun(): nil
---@field public open8              fun(): nil
---@field public open9              fun(): nil
---@field public open10             fun(): nil
---@field public open11             fun(): nil
---@field public open12             fun(): nil
---@field public open13             fun(): nil
---@field public open14             fun(): nil
---@field public open15             fun(): nil
---@field public open16             fun(): nil
---@field public open17             fun(): nil
---@field public open18             fun(): nil
---@field public open19             fun(): nil
---@field public open20             fun(): nil
local M = {}

function M.open(tab)
  local tab_current = vim.fn.tabpagenr() ---@type integer
  if tab_current == tab then
    return
  end

  local tab_count = vim.fn.tabpagenr("$") ---@type integer
  local tabid_next = fml.fn.navigate_limit(0, tab, tab_count)
  local tabpages = vim.api.nvim_list_tabpages()
  local tabnr_next = tabpages[tabid_next]
  vim.api.nvim_set_current_tabpage(tabnr_next)
end

for i = 1, 20 do
  M['open' .. i] = function()
    M.open(i)
  end
end

---Opens tabpage after the last one
---@return nil
function M.new_tab()
  vim.cmd("$tabnew")
end

return M
