local Observable = require("eve.collection.observable")
local std_array = require("eve.std.array")
local reporter = require("eve.std.reporter")

---@class fml.api.state
local M = require("fml.api.state.mod")

---@param tabnr                         integer
---@return fml.types.api.state.ITabItem|nil
function M.get_tab(tabnr)
  if M.tabs[tabnr] == nil then
    M.refresh_tab(tabnr)
  end

  local tab = M.tabs[tabnr] ---@type fml.types.api.state.ITabItem|nil
  if tab == nil then
    reporter.error({
      from = "fml.api.state",
      subject = "get_tab",
      message = "Cannot find tab from the state",
      details = { tabnr = tabnr },
    })
  end
  return tab
end

---@return integer
function M.get_current_tab_winnr()
  local tabnr = vim.api.nvim_get_current_tabpage() ---@type integer
  local tab = M.tabs[tabnr] ---@type fml.types.api.state.ITabItem|nil
  if tab ~= nil then
    local winnr = tab.winnr_cur:snapshot() ---@type integer
    if winnr ~= 0 and vim.api.nvim_win_is_valid(winnr) then
      return winnr
    end
  end
  return vim.api.nvim_tabpage_get_win(tabnr)
end

---@return nil
function M.refresh_tabs()
  local tabnrs = vim.api.nvim_list_tabpages() ---@type integer[]
  local tabs = {} ---@type table<integer, fml.types.api.state.ITabItem>
  for _, tabnr in ipairs(tabnrs) do
    local tab = M.refresh_tab(tabnr) ---@type fml.types.api.state.ITabItem|nil
    if tab ~= nil then
      tabs[tabnr] = tab
    end
  end

  M.tabs = tabs
end

---@param tabnr                         integer|nil
---@return fml.types.api.state.ITabItem|nil
function M.refresh_tab(tabnr)
  if tabnr == nil or type(tabnr) ~= "number" then
    return
  end

  if not M.validate_tab(tabnr) then
    M.tabs[tabnr] = nil
    return
  end

  local bufnr_set = {} ---@type table<integer, boolean>
  local bufnrs = {} ---@type integer[]
  local winnrs = std_array.filter_inline(vim.api.nvim_tabpage_list_wins(tabnr), M.validate_win) ---@type integer[]

  local tab = M.tabs[tabnr] ---@type fml.types.api.state.ITabItem|nil
  if tab == nil then
    local winnr_cur = vim.api.nvim_tabpage_get_win(tabnr) ---@type integer
    winnr_cur = std_array.contains(winnrs, winnr_cur) and winnr_cur or winnrs[1] or winnr_cur

    ---@type fml.types.api.state.ITabItem
    tab = {
      name = eve.constants.TAB_UNNAMED,
      bufnrs = {},
      bufnr_set = {},
      winnr_cur = Observable.from_value(winnr_cur),
    }
    M.tabs[tabnr] = tab
  else
    for _, bufnr in ipairs(tab.bufnrs) do
      if not bufnr_set[bufnr] and M.validate_buf(bufnr) then
        bufnr_set[bufnr] = true
        table.insert(bufnrs, bufnr)
      end
    end
  end

  ---! Add bufs in windows of the tab to the tab.bufnrs.
  for _, winnr in ipairs(winnrs) do
    local bufnr = vim.api.nvim_win_get_buf(winnr) ---@type integer
    if not bufnr_set[bufnr] and M.validate_buf(bufnr) then
      bufnr_set[bufnr] = true
      table.insert(bufnrs, bufnr)
    end
  end

  tab.bufnrs = bufnrs
  tab.bufnr_set = bufnr_set
  return tab
end
