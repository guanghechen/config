---@class fml.api.tab
local M = {}

---@param tabnr                         integer
---@return t.eve.context.state.tab.IItem|nil
function M.get(tabnr)
  if eve.context.state.tabs[tabnr] == nil then
    M.refresh(tabnr)
  end

  local tab = eve.context.state.tabs[tabnr] ---@type t.eve.context.state.tab.IItem|nil
  if tab == nil then
    eve.reporter.error({
      from = "fml.api.tab",
      subject = "get_tab",
      message = "Cannot find tab from the state",
      details = { tabnr = tabnr },
    })
  end
  return tab
end

---@param tabnr                         integer the stable unique number of the tabpage
---@return nil
function M.go(tabnr)
  local tabnr_from = vim.api.nvim_get_current_tabpage() ---@type integer
  if tabnr_from ~= tabnr then
    vim.api.nvim_set_current_tabpage(tabnr)
    eve.context.state.tab_history:push(tabnr)
  end
end

---@return integer
function M.get_current_winnr()
  local tabnr = vim.api.nvim_get_current_tabpage() ---@type integer
  local tab = eve.context.state.tabs[tabnr] ---@type t.eve.context.state.tab.IItem|nil
  if tab ~= nil then
    local winnr = tab.winnr_cur:snapshot() ---@type integer
    if winnr ~= 0 and vim.api.nvim_win_is_valid(winnr) then
      return winnr
    end
  end
  return vim.api.nvim_tabpage_get_win(tabnr)
end

---@param tabnr                         integer|nil
---@return t.eve.context.state.tab.IItem|nil
function M.refresh(tabnr)
  if tabnr == nil or type(tabnr) ~= "number" then
    return
  end

  if not eve.tab.is_valid(tabnr) then
    eve.context.state.tabs[tabnr] = nil
    return
  end

  local bufnr_set = {} ---@type table<integer, boolean>
  local bufnrs = {} ---@type integer[]
  local winnrs = eve.array.filter_inline(vim.api.nvim_tabpage_list_wins(tabnr), eve.win.is_valid) ---@type integer[]

  local tab = eve.context.state.tabs[tabnr] ---@type t.eve.context.state.tab.IItem|nil
  if tab == nil then
    local winnr_cur = vim.api.nvim_tabpage_get_win(tabnr) ---@type integer
    winnr_cur = eve.array.contains(winnrs, winnr_cur) and winnr_cur or winnrs[1] or winnr_cur

    ---@type t.eve.context.state.tab.IItem
    tab = {
      name = eve.constants.TAB_UNNAMED,
      bufnrs = {},
      bufnr_set = {},
      winnr_cur = eve.c.Observable.from_value(winnr_cur),
    }
    eve.context.state.tabs[tabnr] = tab
  else
    for _, bufnr in ipairs(tab.bufnrs) do
      if not bufnr_set[bufnr] and eve.buf.is_valid(bufnr) then
        bufnr_set[bufnr] = true
        table.insert(bufnrs, bufnr)
      end
    end
  end

  ---! Add bufs in windows of the tab to the tab.bufnrs.
  for _, winnr in ipairs(winnrs) do
    local bufnr = vim.api.nvim_win_get_buf(winnr) ---@type integer
    if not bufnr_set[bufnr] and eve.buf.is_valid(bufnr) then
      bufnr_set[bufnr] = true
      table.insert(bufnrs, bufnr)
    end
  end

  tab.bufnrs = bufnrs
  tab.bufnr_set = bufnr_set
  return tab
end

---@return nil
function M.refresh_all()
  local tabnrs = vim.api.nvim_list_tabpages() ---@type integer[]
  local tabs = {} ---@type table<integer, t.eve.context.state.tab.IItem>
  for _, tabnr in ipairs(tabnrs) do
    local tab = M.refresh(tabnr) ---@type t.eve.context.state.tab.IItem|nil
    if tab ~= nil then
      tabs[tabnr] = tab
    end
  end

  eve.context.state.tabs = tabs
end

---@type fun(): nil
M.schedule_refresh_all = eve.scheduler.schedule("fml.api.tab.refresh_all", M.refresh_all)

return M
