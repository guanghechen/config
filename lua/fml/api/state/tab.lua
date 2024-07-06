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

---@class fml.api.state.ITabItem
---@field public name                   string
---@field public bufnrs                 integer[]
---@field public bufnr_set              table<integer, boolean>

---@class fml.api.state
---@field public TAB_UNAMED             string
---@field public tabs                   table<integer, fml.api.state.ITabItem>
---@field public tab_history            fml.types.collection.IHistory
---@field public validate_tab           fun(tabnr: integer): boolean
local M = require("fml.api.state.mod")

M.TAB_UNAMED = "unnamed"
M.tabs = {}
M.tab_history = History.new({ name = "tabs", max_count = 100, validate = validate_tab })
M.validate_tab = validate_tab

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
      name = M.TAB_UNAMED,
      bufnrs = {},
      bufnr_set = {},
    }
    M.tabs[tabnr] = tab
  end

  local bufnr_set = tab.bufnr_set or {} ---@type table<integer, boolean>
  local winnrs = vim.api.nvim_tabpage_list_wins(tabnr) ---@type integer[]
  for _, winnr in ipairs(winnrs) do
    local bufnr = vim.api.nvim_win_get_buf(winnr)
    bufnr_set[bufnr] = true
  end

  local bufnr_used_set = {} ---@type table<integer, boolean>
  std_array.filter_inline(tab.bufnrs, function(bufnr)
    bufnr_used_set[bufnr] = true
    return bufnr_set[bufnr]
  end)
  for bufnr in pairs(bufnr_set) do
    if not bufnr_used_set[bufnr] then
      table.insert(tab.bufnrs, bufnr)
    end
  end

  M.refresh_wins(tabnr)
end
