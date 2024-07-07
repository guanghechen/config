local constant = require("fml.constant")
local History = require("fml.collection.history")
local std_array = require("fml.std.array")
local std_object = require("fml.std.object")
local reporter = require("fml.std.reporter")

---@param tabnr                         integer
---@return boolean
local function validate_tab(tabnr)
  return vim.api.nvim_tabpage_is_valid(tabnr)
end

---@param tabnrs                        integer[]
---@param history                       fml.types.collection.IHistory
---@return nil
local function rearrange_tab_history(tabnrs, history)
  std_array.filter_inline(tabnrs, validate_tab)
  local reverse_list = {} ---@type integer[]
  local tabnr_set = {} ---@type table<integer, boolean>

  local prev_present_index = history:present_index() ---@type integer
  local next_present_index = 0 ---@type integer
  for element, idx in history:iterator() do
    table.insert(reverse_list, element)
    if prev_present_index == idx then
      next_present_index = #reverse_list
    end
  end

  next_present_index = #reverse_list - next_present_index + 1
  history:clear()
  for i = #tabnrs, 1, -1 do
    local tabnr = tabnrs[i]
    if not tabnr_set[tabnr] then
      history:push(tabnr)
      next_present_index = next_present_index + 1
    end
  end
  for i = #reverse_list, 1, -1 do
    history:push(reverse_list[i])
  end

  if next_present_index == 0 then
    local tabnr = tabnrs[1] or vim.api.nvim_list_bufs()[1] ---@type integer|nil
    if tabnr then
      history:push(tabnr)
    end
  else
    history:go(next_present_index)
  end
end


---@class fml.api.state
---@field public tabs                   table<integer, fml.api.state.ITabItem>
---@field public tab_history            fml.types.collection.IHistory
---@field public validate_tab           fun(tabnr: integer): boolean
local M = require("fml.api.state.mod")

M.tabs = {}
M.tab_history = History.new({
  name = "tabs",
  capacity = constant.TAB_HISTORY_CAPACITY,
  validate = validate_tab,
})
M.validate_tab = validate_tab

---@param tabnr                         integer
---@return nil
function M.close_tab(tabnr)
  M.tabs[tabnr] = nil

  if validate_tab(tabnr) then
    vim.api.nvim_set_current_tabpage(tabnr)
    vim.cmd("tabclose")
  end

  local tabnr_last = M.tab_history:present() ---@type integer|nil
  if tabnr_last ~= nil then
    vim.api.nvim_set_current_tabpage(tabnr_last)
  end
  M.refresh_tabs()
end

---@return fml.api.state.ITabItem|nil, integer
function M.get_current_tab()
  local tabnr = vim.api.nvim_get_current_tabpage() ---@type integer
  if M.tabs[tabnr] == nil then
    M.refresh_tab(tabnr)
  end

  local tab = M.tabs[tabnr] ---@type fml.api.state.ITabItem|nil
  if tab == nil then
    reporter.error({
      from = "fml.api.state",
      subject = "get_current_tab",
      message = "Cannot find tab from the state",
      details = { tabnr = tabnr },
    })
  end
  return tab, tabnr
end

---@return nil
function M.refresh_tabs()
  local tabnrs = vim.api.nvim_list_tabpages() ---@type integer[]
  local valid_tabnr_set = {} ---@type table<integer, boolean>
  for _, tabnr in ipairs(tabnrs) do
    valid_tabnr_set[tabnr] = true
    M.refresh_tab(tabnr)
  end
  std_object.filter_inline(M.tabs, function(tabnr)
    return not not valid_tabnr_set[tabnr]
  end)

  rearrange_tab_history(tabnrs, M.tab_history)
end

---@param tabnr                         integer|nil
---@return nil
function M.refresh_tab(tabnr)
  if tabnr == nil or type(tabnr) ~= "number" then
    return
  end

  if not validate_tab(tabnr) then
    M.tabs[tabnr] = nil
    return
  end

  local tab = M.tabs[tabnr] ---@type fml.api.state.ITabItem|nil
  if tab == nil then
    ---@type fml.api.state.ITabItem
    tab = {
      name = constant.TAB_UNNAMED,
      bufnrs = {},
    }
    M.tabs[tabnr] = tab
  end

  local bufnr_set = {} ---@type table<integer, boolean>
  for _, bufnr in ipairs(tab.bufnrs) do
    bufnr_set[bufnr] = true
  end

  local winnrs = vim.api.nvim_tabpage_list_wins(tabnr) ---@type integer[]
  for _, winnr in ipairs(winnrs) do
    local bufnr = vim.api.nvim_win_get_buf(winnr)
    bufnr_set[bufnr] = true
  end

  std_array.filter_inline(tab.bufnrs, function(bufnr)
    local ok = bufnr_set[bufnr]
    bufnr_set[bufnr] = nil
    return ok
  end)
  for bufnr in pairs(bufnr_set) do
    table.insert(tab.bufnrs, bufnr)
  end

  M.refresh_wins(tabnr)
end
