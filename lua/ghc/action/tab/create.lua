---@class ghc.action.tab
local M = require("ghc.action.tab.mod")

---@param name                          ?string|nil
---@param bufnr                         ?integer
---@return integer
function M.create(name, bufnr)
  vim.cmd("$tabnew")

  local tabnr = vim.api.nvim_get_current_tabpage() ---@type integer
  eve.context.state.tab_history:push(tabnr)

  if bufnr ~= nil then
    local winnr = vim.api.nvim_get_current_win() ---@type integer
    vim.api.nvim_win_set_buf(winnr, bufnr)
  end

  vim.schedule(function()
    fml.api.tab.refresh(tabnr)
    if name and eve.context.state.tabs[tabnr] then
      eve.context.state.tabs[tabnr].name = name
    end

    local tab = eve.context.state.tabs[tabnr] ---@type t.eve.context.state.tab.IItem
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
  local tabnr, tab = eve.object.find(eve.context.state.tabs, function(tab)
    return tab.name == name
  end)

  if tabnr ~= nil and vim.api.nvim_tabpage_is_valid(tabnr) then
    if tab == nil then
      fml.api.tab.refresh(tabnr)
    end

    vim.api.nvim_set_current_tabpage(tabnr)
    local winnrs = vim.api.nvim_tabpage_list_wins(tabnr) ---@type integer[]
    local _, winnr = eve.array.first(winnrs, function(winnr)
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
