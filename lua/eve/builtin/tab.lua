local checks = require("eve.builtin.checks")
local constant = require("eve.builtin.constant")

---@class eve.builtin.tab.Meta : eve.t.state.state.tab.IMeta
---@field public tabnr                  integer
---@field public tabtype                string
---@field public winnr_listed           integer
---@field public bufs                   eve.t.state.state.tab.meta.IBuf[]
local Meta = {}
Meta.__index = Meta

---@param tabnr                        integer
---@param tabtype                      string|nil
---@param winnr_listed                 integer|nil
---@param bufs                         eve.t.state.state.tab.meta.IBuf[]|nil
---@return eve.builtin.tab.Meta
function Meta.new(tabnr, tabtype, winnr_listed, bufs)
  local self = setmetatable({}, Meta)
  self.tabnr = tabnr ---@type integer
  self.tabtype = tabtype or constant.TT_NORMAL ---@type string
  self.winnr_listed = winnr_listed or 0 ---@type integer
  self.bufs = bufs or {} ---@type eve.t.state.state.tab.meta.IBuf[]
  return self
end

---@return eve.t.state.data.tab.IMeta
function Meta:dump()
  local tabnr = self.tabnr ---@type integer
  local tabtype = self.tabtype ---@type string
  local bufs = self.bufs ---@type eve.t.state.state.tab.meta.IBuf[]

  ---@type eve.t.state.data.tab.IMeta
  local data = {
    tabnr = tabnr,
    tabtype = tabtype,
    bufs = bufs,
  }
  return data
end

---@return eve.t.state.state.tab.meta.IBuf|nil
---@return integer|nil
function Meta:find_buf(bufnr)
  for index, buf in ipairs(self.bufs) do
    if buf.bufnr == bufnr then
      return buf, index
    end
  end
  return nil, nil
end

---@param bufnr                         integer
---@return nil
function Meta:toggle_pin(bufnr)
  local bufs = self.bufs ---@type eve.t.state.state.tab.meta.IBuf[]
  local buf, i = self:find_buf(bufnr)
  if i == nil or buf == nil then
    return
  end

  if buf.pinned then
    local j = i + 1 ---@type integer
    while j <= #bufs do
      if not bufs[j].pinned then
        break
      end

      bufs[j - 1] = buf[j]
      j = j + 1
    end
    bufs[j - 1] = buf
    return
  end

  local j = i - 1 ---@type integer
  while j >= 1 do
    if bufs[j].pinned then
      break
    end
    bufs[j + 1] = bufs[j]
    j = j - 1
  end

  buf.pinned = not buf.pinned
  bufs[j + 1] = buf
end

local meta_map = {} ---@type table<integer, eve.t.state.state.tab.IMeta>

---@class eve.builtin.tab
---@field public Meta                     eve.builtin.tab.Meta
local M = { Meta = Meta }

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

---@param tabnr                         integer
---@return table<integer, boolean>
function M.get_visible_bufnrs(tabnr)
  local winnrs = vim.api.nvim_tabpage_list_wins(tabnr) ---@type integer[]
  local bufnrs = {} ---@type table<integer, boolean>
  for _, winnr in ipairs(winnrs) do
    local bufnr = vim.api.nvim_win_get_buf(winnr) ---@type integer
    bufnrs[bufnr] = true
  end
  return bufnrs
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
  local meta = M.get_meta(tabnr) ---@type eve.t.state.state.tab.IMeta|nil
  if meta ~= nil then
    return meta
  end

  if tabnr == nil or not checks.is_tab_valid(tabnr) then
    return nil
  end

  local tabtype = M.calc_tabtype(tabnr) ---@type string

  local bufs = {} ---@type eve.t.state.data.tab.meta.IBuf[]
  local bufnr_set = {} ---@type table<integer, true>
  local winnrs = vim.api.nvim_tabpage_list_wins(tabnr) ---@type integer[]
  for _, winnr in ipairs(winnrs) do
    if not checks.is_win_floating(winnr) then
      local bufnr = vim.api.nvim_win_get_buf(winnr) ---@type integer
      if not bufnr_set[bufnr] and checks.is_buf_valid(bufnr) then
        bufnr_set[bufnr] = true
        bufs[#bufs + 1] = { bufnr = bufnr, pinned = false } ---@type eve.t.state.state.tab.meta.IBuf
      end
    end
  end

  ---@type eve.t.state.state.tab.IMeta
  meta = Meta.new(tabnr, tabtype, 0, bufs)
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
  for _, winnr in ipairs(winnrs) do
    local bufnr = vim.api.nvim_win_get_buf(winnr) ---@type integer
    if not meta:find_buf(bufnr) then
      meta.bufs[#meta.bufs + 1] = { bufnr = bufnr, pinned = false } ---@type eve.t.state.state.tab.meta.IBuf
    end
  end

  local k = 1 ---@type integer
  local N = #meta.bufs ---@type integer
  for i = 1, N, 1 do
    local buf = meta.bufs[i] ---@type eve.t.state.state.tab.meta.IBuf
    if checks.is_buf_valid(buf.bufnr) then
      meta.bufs[k] = buf
      k = k + 1
    end
  end
  for i = k, N, 1 do
    meta.bufs[i] = nil
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

---@param winnr                        integer
---@param bufnr                        integer
---@return nil
function M.on_buf_enter(winnr, bufnr)
  if not checks.is_win_valid(winnr) or not checks.is_buf_valid(bufnr) then
    return
  end

  local tabnr = vim.api.nvim_get_current_tabpage() ---@type integer
  local meta = M.resolve(tabnr) ---@type eve.t.state.state.tab.IMeta|nil
  if meta == nil then
    return
  end

  meta.winnr_listed = winnr
  if not meta:find_buf(bufnr) then
    meta.bufs[#meta.bufs + 1] = { bufnr = bufnr, pinned = false } ---@type eve.t.state.state.tab.meta.IBuf
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
  local N = #meta.bufs ---@type integer
  for i = 1, N, 1 do
    local buf = meta.bufs[i] ---@type eve.t.state.state.tab.meta.IBuf
    if not vim.list_contains(bufnrs, buf.bufnr) then
      meta.bufs[k] = buf
      k = k + 1
    end
  end
  for i = k, N, 1 do
    meta.bufs[i] = nil
  end
end

----------------------------------------------------------------------------------------------------

---@param tabnr                                         integer
---@param bufnr                                         integer
---@return boolean
function M.has_buf(tabnr, bufnr)
  local meta = M.resolve(tabnr) ---@type eve.t.state.state.tab.IMeta|nil
  return meta ~= nil and meta:find_buf(bufnr) ~= nil
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
