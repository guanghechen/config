local state = require("fml.api.state")
local std_array = require("eve.std.array")
local std_object = require("eve.std.object")

---@class fml.api.tab
local M = require("fml.api.tab.mod")

---@param name                          ?string|nil
---@param bufnr                         ?integer
---@return integer
function M.create(name, bufnr)
  vim.cmd("$tabnew")

  local tabnr = vim.api.nvim_get_current_tabpage() ---@type integer
  state.tab_history:push(tabnr)

  if bufnr ~= nil then
    local winnr = vim.api.nvim_get_current_win() ---@type integer
    vim.api.nvim_win_set_buf(winnr, bufnr)
  end

  vim.schedule(function()
    state.refresh_tab(tabnr)
    if name and state.tabs[tabnr] then
      state.tabs[tabnr].name = name
    end

    local tab = state.tabs[tabnr] ---@type fml.types.api.state.ITabItem
    if bufnr ~= nil and tab ~= nil and #tab.bufnrs > 1 then
      tab.bufnrs = { bufnr }
      tab.bufnr_set = { [bufnr] = true }
    end
  end)

  return tabnr
end

---@param name                          string
---@param bufnr                         ?integer
---@return integer
function M.create_if_nonexist(name, bufnr)
  local tabnr, tab = std_object.find(state.tabs, function(tab)
    return tab.name == name
  end)

  if tabnr ~= nil and vim.api.nvim_tabpage_is_valid(tabnr) then
    if tab == nil then
      state.refresh_tab(tabnr)
    end

    vim.api.nvim_set_current_tabpage(tabnr)
    local winnrs = vim.api.nvim_tabpage_list_wins(tabnr) ---@type integer[]
    local _, winnr = std_array.first(winnrs, function(winnr)
      local win_bufnr = vim.api.nvim_win_get_buf(winnr) ---@type integer
      return win_bufnr == bufnr
    end)
    if winnr ~= nil then
      vim.api.nvim_set_current_win(winnr)
    end
  else
    tabnr = M.create(name, bufnr) ---@type integer
  end
  return tabnr
end

---@param name                          ?string
---@return integer
function M.create_with_buf(name)
  local winnr = vim.api.nvim_get_current_win()
  local bufnr = vim.api.nvim_win_get_buf(winnr)
  local cursor = vim.api.nvim_win_get_cursor(winnr)
  local tabnr = M.create(name, bufnr)

  vim.api.nvim_win_set_cursor(winnr, cursor)
  return tabnr
end
