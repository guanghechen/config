---@class fml.api.tab
---@field public goto_tab1              fun(): nil
---@field public goto_tab2              fun(): nil
---@field public goto_tab3              fun(): nil
---@field public goto_tab4              fun(): nil
---@field public goto_tab5              fun(): nil
---@field public goto_tab6              fun(): nil
---@field public goto_tab7              fun(): nil
---@field public goto_tab8              fun(): nil
---@field public goto_tab9              fun(): nil
---@field public goto_tab10             fun(): nil
---@field public goto_tab11             fun(): nil
---@field public goto_tab12             fun(): nil
---@field public goto_tab13             fun(): nil
---@field public goto_tab14             fun(): nil
---@field public goto_tab15             fun(): nil
---@field public goto_tab16             fun(): nil
---@field public goto_tab17             fun(): nil
---@field public goto_tab18             fun(): nil
---@field public goto_tab19             fun(): nil
---@field public goto_tab20             fun(): nil
local M = {}

function M.goto_tab(tab)
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
  M['goto_tab' .. i] = function()
    M.goto_tab(i)
  end
end

---Opens tabpage after the last one
---@return nil
function M.new_tab()
  vim.cmd("$tabnew")
end

return M
