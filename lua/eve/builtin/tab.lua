local checks = require("eve.builtin.checks")
local constant = require("eve.builtin.constant")

local meta_map = {} ---@type table<integer, eve.t.state.state.tab.IMeta>

---@class eve.builtin.tab
local M = {}

---@param tabnr                         integer|nil
---@return eve.t.state.state.tab.IMeta|nil
function M.get_meta(tabnr)
  if tabnr ~= nil and vim.api.nvim_tabpage_is_valid(tabnr) then
    return meta_map[tabnr]
  end
end

---@param tabnr                         integer|nil
---@param meta                          eve.t.state.state.tab.IMeta|nil
---@return eve.t.state.state.tab.IMeta|nil
function M.set_meta(tabnr, meta)
  if tabnr ~= nil and vim.api.nvim_tabpage_is_valid(tabnr) then
    meta_map[tabnr] = meta
    return meta
  end
end

---@param tabnr                         integer|nil
---@return nil
function M.del_meta(tabnr)
  if tabnr ~= nil then
    meta_map[tabnr] = nil
  end
end

---@return eve.t.state.state.tab.IMeta|nil
function M.get_current()
  local tabnr = vim.api.nvim_get_current_tabpage() ---@type integer
  return M.resolve(tabnr)
end

---@return integer
function M.get_current_winnr()
  local tabnr = vim.api.nvim_get_current_tabpage() ---@type integer
  local meta = M.resolve(tabnr) ---@type eve.t.state.state.tab.IMeta|nil
  return meta and meta.winnr_listed or 0
end

---@return integer
function M.get_current_bufnr()
  local tabnr = vim.api.nvim_get_current_tabpage() ---@type integer
  local meta = M.resolve(tabnr) ---@type eve.t.state.state.tab.IMeta|nil
  local winnr = meta and meta.winnr_listed or 0 ---@type integer
  return winnr > 0 and vim.api.nvim_win_is_valid(winnr) and vim.api.nvim_win_get_buf(winnr) or 0
end

---@protected
---@param tabnr                         integer
---@return string
function M.calc_tabtype(tabnr)
  local winnrs = vim.api.nvim_tabpage_list_wins(tabnr) ---@type integer[]

  ---! Check if the diffview tab
  for _, winnr in ipairs(winnrs) do
    local bufnr = vim.api.nvim_win_get_buf(winnr) ---@type integer
    local filetype = vim.bo[bufnr].filetype ---@type string
    if filetype == constant.FT_DIFFVIEW_FILES or filetype == constant.FT_DIFFVIEW_FILE_HISTORY then
      return constant.TT_DIFFVIEW
    end
  end

  return constant.TT_NORMAL ---@type string
end

---@param tabnr                         integer|nil
---@return eve.t.state.state.tab.IMeta|nil
function M.resolve(tabnr)
  if tabnr == nil or not checks.is_tab_valid(tabnr) then
    return nil
  end

  local meta = M.get_meta(tabnr) ---@type eve.t.state.state.tab.IMeta|nil
  if meta ~= nil then
    return meta
  end

  local bufnrs = {} ---@type integer[]
  local winnrs = vim.api.nvim_tabpage_list_wins(tabnr) ---@type integer[]
  for _, winnr in ipairs(winnrs) do
    if not checks.is_win_floating(winnr) then
      local bufnr = vim.api.nvim_win_get_buf(winnr) ---@type integer
      if not vim.list_contains(bufnrs, bufnr) and checks.is_buf_valid(bufnr) then
        table.insert(bufnrs, bufnr)
      end
    end
  end

  local tabtype = M.calc_tabtype(tabnr) ---@type string

  ---@type eve.t.state.state.tab.IMeta
  meta = {
    tabtype = tabtype,
    bufnrs = bufnrs,
    winnr_listed = 0,
  }
  return M.set_meta(tabnr, meta)
end

---@param tabnr                         integer|nil
---@return eve.t.state.state.tab.IMeta|nil
function M.refresh(tabnr)
  if tabnr == nil then
    return
  end

  local meta = M.get_meta(tabnr) ---@type eve.t.state.state.tab.IMeta|nil
  if meta == nil then
    return M.resolve(tabnr)
  end

  local winnrs = vim.api.nvim_tabpage_list_wins(tabnr) ---@type integer[]
  local bufnrs = meta.bufnrs ---@type integer[]
  for _, winnr in ipairs(winnrs) do
    local bufnr = vim.api.nvim_win_get_buf(winnr) ---@type integer
    if not vim.list_contains(bufnrs, bufnr) then
      table.insert(bufnrs, bufnr)
    end
  end

  local k = 1 ---@type integer
  local N = #bufnrs ---@type integer
  for i = 1, N, 1 do
    local bufnr = bufnrs[i] ---@type integer
    if checks.is_buf_valid(bufnr) then
      bufnrs[k] = bufnr
      k = k + 1
    end
  end
  for i = k, N, 1 do
    bufnrs[i] = nil
  end

  if not checks.is_win_valid(meta.winnr_listed) then
    local winnr_cur = vim.api.nvim_tabpage_get_win(tabnr) ---@type integer
    if checks.is_win_valid(winnr_cur) then
      meta.winnr_listed = winnr_cur
    else
      for _, winnr in ipairs(winnrs) do
        if checks.is_win_valid(winnr_cur) then
          meta.winnr_listed = winnr
          break
        end
      end
    end
  end

  local tabtype = M.calc_tabtype(tabnr) ---@type string
  meta.tabtype = tabtype

  return meta
end

---@return nil
function M.refresh_all()
  local tabnrs = vim.api.nvim_list_tabpages() ---@type integer[]
  for _, tabnr in ipairs(tabnrs) do
    M.refresh(tabnr)
  end

  local invalid_tabnrs = {} ---@type integer[]
  for tabnr in pairs(meta_map) do
    if tabnr < 1 or not vim.api.nvim_tabpage_is_valid(tabnr) then
      table.insert(invalid_tabnrs, tabnr)
    end
  end
  for _, tabnr in ipairs(invalid_tabnrs) do
    M.del_meta(tabnr)
  end
end

---@param bufnr                        integer|nil
---@return nil
function M.on_buf_enter(bufnr)
  if bufnr == nil or not checks.is_buf_valid(bufnr) then
    return
  end

  local tabnr = vim.api.nvim_get_current_tabpage() ---@type integer
  local meta = M.resolve(tabnr) ---@type eve.t.state.state.tab.IMeta|nil
  if meta == nil then
    return
  end

  if not vim.list_contains(meta.bufnrs, bufnr) then
    table.insert(meta.bufnrs, bufnr)
  end
end

---@param bufnrs integer[]
---@return nil
function M.on_bufs_close(bufnrs)
  if #bufnrs < 1 then
    return
  end

  local tabnr = vim.api.nvim_get_current_tabpage() ---@type integer
  local meta = M.resolve(tabnr) ---@type eve.t.state.state.tab.IMeta|nil
  if meta == nil then
    return
  end

  local k = 1 ---@type integer
  local N = #meta.bufnrs ---@type integer
  for i = 1, N, 1 do
    local bufnr = meta.bufnrs[i] ---@type integer
    if not vim.list_contains(bufnrs, bufnr) then
      meta.bufnrs[k] = bufnr
      k = k + 1
    end
  end

  for i = k, N, 1 do
    meta.bufnrs[i] = nil
  end
end

----------------------------------------------------------------------------------------------------

---@param tabnr                                         integer
---@param bufnr                                         integer
---@return boolean
function M.has_buf(tabnr, bufnr)
  local meta = M.resolve(tabnr) ---@type eve.t.state.state.tab.IMeta|nil
  return meta ~= nil and vim.list_contains(meta.bufnrs, bufnr)
end

---@param bufnrs                        integer[]
---@return integer
function M.remove_unrefereced_bufs(bufnrs)
  local tabnrs = vim.api.nvim_list_tabpages() ---@type integer[]
  local bufnrs_to_remove = {} ---@type integer[]

  for _, bufnr in ipairs(bufnrs) do
    if checks.is_buf_valid(bufnr) then
      local has_copy = false ---@type boolean
      for _, tabnr in ipairs(tabnrs) do
        if M.has_buf(tabnr, bufnr) then
          has_copy = true
          break
        end
      end
      if not has_copy then
        table.insert(bufnrs_to_remove, bufnr)
      end
    end
  end

  for _, bufnr in ipairs(bufnrs_to_remove) do
    vim.api.nvim_buf_delete(bufnr, { force = true })
  end
  return #bufnrs_to_remove
end

return M
