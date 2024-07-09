local state = require("fml.api.state")
local std_array = require("fml.std.array")
local std_object = require("fml.std.object")

---@class fml.api.tab
local M = require("fml.api.tab.mod")

---@param name                          ?string|nil
---@param bufnr                         ?integer
---@return nil
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

    if bufnr == nil and state.tabs[tabnr] and #state.tabs[tabnr].bufnrs > 1 then
      local tab = state.tabs[tabnr] ---@type fml.api.state.ITabItem
      local bufnr_cur = vim.api.nvim_get_current_buf() ---@type integer
      if tab.bufnr_set[bufnr_cur] ~= nil then
        tab.bufnrs = { bufnr_cur }
        tab.bufnr_set = { [bufnr_cur] = true }
      end
    end
  end)
end

---@param name                          string
---@param bufnr                         ?integer
---@return nil
function M.create_if_nonexist(name, bufnr)
  local tabnr, tab = std_object.find(state.tabs, function(tab)
    return tab.name == name
  end)

  if tabnr ~= nil and tab ~= nil then
    vim.api.nvim_set_current_tabpage(tabnr)
    local winnrs = vim.api.nvim_tabpage_list_wins(tabnr) ---@type integer[]
    local winnr = std_array.first(winnrs, function(winnr)
      local win_bufnr = vim.api.nvim_win_get_buf(winnr) ---@type integer
      return win_bufnr == bufnr
    end)
    if winnr ~= nil then
      vim.api.nvim_set_current_win(winnr)
    end
  else
    M.create(name, bufnr)
  end
end

---@param name                          ?string
function M.create_with_buf(name)
  local winnr = vim.api.nvim_get_current_win()
  local bufnr = vim.api.nvim_win_get_buf(winnr)
  local cursor = vim.api.nvim_win_get_cursor(winnr)

  M.create(name, bufnr)

  vim.api.nvim_win_set_cursor(winnr, cursor)
end
