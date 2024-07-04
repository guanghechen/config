local state = require("fml.api.state")
local navigate_limit = require("fml.fn.navigate_limit")
local navigate_circular = require("fml.fn.navigate_circular")

---@class fml.api.tab
---@field public focus_1                fun(): nil
---@field public focus_2                fun(): nil
---@field public focus_3                fun(): nil
---@field public focus_4                fun(): nil
---@field public focus_5                fun(): nil
---@field public focus_6                fun(): nil
---@field public focus_7                fun(): nil
---@field public focus_8                fun(): nil
---@field public focus_9                fun(): nil
---@field public focus_10               fun(): nil
local M = require("fml.api.tab.mod")

---@param tabnr                         integer the stable unique number of the tabpage
---@return nil
function M.go(tabnr)
  local tabnr_from = vim.api.nvim_get_current_tabpage() ---@type integer
  if tabnr_from ~= tabnr then
    vim.api.nvim_set_current_tabpage(tabnr)
    state.tab_history:push(tabnr)
  end
end

---@param tabid                         integer the index of tab list
---@return nil
function M.focus(tabid)
  local tab_count = vim.fn.tabpagenr("$") ---@type integer
  local tabid_next = navigate_limit(0, tabid, tab_count)
  local tabpages = vim.api.nvim_list_tabpages()
  local tabnr_next = tabpages[tabid_next]
  M.go(tabnr_next)
end

for i = 1, 10 do
  M["focus_" .. i] = function()
    M.focus(i)
  end
end

function M.focus_left()
  local tabid_cur = vim.fn.tabpagenr() ---@type integer
  local tab_count = vim.fn.tabpagenr("$") ---@type integer
  local tabid_next = navigate_circular(tabid_cur, -1, tab_count)
  local tabpages = vim.api.nviwism_list_tabpages()
  local tabnr_next = tabpages[tabid_next]
  M.go(tabnr_next)
end

function M.focus_right()
  local tabid_cur = vim.fn.tabpagenr() ---@type integer
  local tab_count = vim.fn.tabpagenr("$") ---@type integer
  local tabid_next = navigate_circular(tabid_cur, 1, tab_count)
  local tabpages = vim.api.nvim_list_tabpages()
  local tabnr_next = tabpages[tabid_next]
  M.go(tabnr_next)
end