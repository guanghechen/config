local state = require("fml.api.state")

---@class fml.api.tab
local M = require("fml.api.tab.mod")

function M.rearrange_history()
  local tab_history_reverse_list = {} ---@type integer[]
  local tab_history_unvisited_list = {} ---@type integer[]
  local tab_history_set = {} ---@type table<integer, boolean>

  while true do
    local tabnr = state.tab_history:present() ---@type integer|nil
    if tabnr == nil then
      break
    end
    local tab = state.tabs[tabnr]
    if tab and vim.api.nvim_tabpage_is_valid(tabnr) then
      tab_history_set[tabnr] = true
      table.insert(tab_history_reverse_list, tabnr)
    end
    state.tab_history:back(1)
  end

  for _, tab in ipairs(state.tabs) do
    if not tab_history_set[tab.tabnr] and vim.api.nvim_tabpage_is_valid(tab.tabnr) then
      table.insert(tab_history_unvisited_list, tab.tabnr)
    end
  end

  state.tab_history:clear()
  for i = #tab_history_unvisited_list, 1, -1 do
    state.tab_history:push(tab_history_unvisited_list[i])
  end
  for i = #tab_history_reverse_list, 1, -1 do
    state.tab_history:push(tab_history_reverse_list[i])
  end
end
