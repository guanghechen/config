local state = require("fml.api.state")

---@class fml.api.tab
local M = require("fml.api.tab.mod")

---@param bufnr                         ?integer
---@param name                          ?string|nil
---@return nil
function M.create(bufnr, name)
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

---@param name                          ?string
function M.create_with_buf(name)
  local winnr = vim.api.nvim_get_current_win()
  local bufnr = vim.api.nvim_win_get_buf(winnr)
  local cursor = vim.api.nvim_win_get_cursor(winnr)

  M.create(bufnr, name)

  vim.api.nvim_win_set_cursor(winnr, cursor)
end
