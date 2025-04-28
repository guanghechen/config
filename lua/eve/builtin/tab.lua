---@alias eve.builtin.tab.TypeEnum
---| "diffview"
---| "normal"

---@class eve.builtin.tab.IBufItem
---@field public bufnr                  integer
---@field public pinned                 boolean

---@class eve.builtin.tab.IMetaData
---@field public bufs                   eve.builtin.tab.IBufItem
---@field public winnr_sourcefile       integer|nil
---@field public tabtype                eve.builtin.tab.TypeEnum

---@class eve.builtin.tab.Types
local Types = {
  DIFFVIEW = "diffview",
  NORMAL = "normal",
}

local meta_map = {} ---@type table<integer, eve.builtin.tab.IMetaData>

---@class eve.builtin.tab
local M = {}

M.Types = vim.deepcopy(Types)

---@param tabnr                         integer|nil
---@return eve.builtin.tab.TypeEnum|nil
function M.get_type(tabnr)
  if tabnr == nil or tabnr < 1 or not vim.api.nvim_tabpage_is_valid(tabnr) then
    return nil
  end
  return vim.t[tabnr].eve_type
end

---@param tabnr                         integer
---@param tabtype                       eve.builtin.tab.TypeEnum|nil
---@return nil
function M.set_type(tabnr, tabtype)
  vim.t[tabnr].eve_type = tabtype
end

----------------------------------------------------------------------------------------------------

---@param tabnr                         integer
---@return boolean
function M.is_valid(tabnr)
  return tabnr > 0 and vim.api.nvim_tabpage_is_valid(tabnr)
end

---@param tabnr                         integer
---@return table<integer, boolean>
function M.list_visible_bufnrs(tabnr)
  local winnrs = vim.api.nvim_tabpage_list_wins(tabnr) ---@type integer[]
  local bufnrs = {} ---@type table<integer, boolean>
  for _, winnr in ipairs(winnrs) do
    local bufnr = vim.api.nvim_win_get_buf(winnr) ---@type integer
    bufnrs[bufnr] = true
  end
  return bufnrs
end

----------------------------------------------------------------------------------------------------

---@param tabnr                         integer|nil
---@param force                         boolean
---@return eve.builtin.tab.IMetaData|nil
function M.resolve(tabnr, force)
  if tabnr == nil or tabnr < 1 or not vim.api.nvim_tabpage_is_valid(tabnr) then
    return nil
  end

  local meta = meta_map[tabnr] ---@type eve.builtin.tab.IMetaData|nil
  if meta ~= nil and not force then
    return meta
  end

  local bufs = {} ---@type eve.builtin.tab.IBufItem[]
  local bufnr_set = {} ---@type table<integer, boolean>
  if meta ~= nil then
    for _, buf in ipairs(meta.bufs) do
      ---@cast buf                      eve.builtin.tab.IBufItem
      local bufnr = buf.bufnr ---@type integer
      local pinned = buf.pinned ---@type boolean
      if vim.api.nvim_buf_is_valid(bufnr) and vim.bo[bufnr].buflisted and not bufnr_set[bufnr] then
        bufnr_set[bufnr] = true
        bufs[#bufs + 1] = { bufnr = bufnr, pinned = pinned }
      end
    end
  end

  local winnrs = vim.api.nvim_tabpage_list_wins(tabnr) ---@type integer[]
  for _, winnr in ipairs(winnrs) do
    local bufnr = vim.api.nvim_win_get_buf(winnr) ---@type integer
    if vim.bo[bufnr].buflisted and not bufnr_set[bufnr] then
      bufnr_set[bufnr] = true
      bufs[#bufs + 1] = { bufnr = bufnr, pinned = false }
    end
  end

  local tabtype = M.resolve_type(tabnr, force) ---@type eve.builtin.tab.TypeEnum

  local winnr_sourcefile = meta and meta.winnr_sourcefile or nil ---@type integer|nil
  if winnr_sourcefile == nil or winnr_sourcefile < 0 or not vim.api.nvim_win_is_valid(winnr_sourcefile) then
    winnr_sourcefile = vim.api.nvim_tabpage_get_win(tabnr)
  end
  if not eve.win.is_sourcefile(winnr_sourcefile) then
    winnr_sourcefile = nil
  end

  ---@type eve.builtin.tab.IMetaData
  meta = {
    bufs = bufs,
    winnr_sourcefile = winnr_sourcefile,
    tabtype = tabtype,
  }
  return meta
end

---@param tabnr                         integer
---@param bufnr                         integer
---@param pinned                        boolean|nil
---@return eve.builtin.tab.IMetaData|nil
function M.add_buf(tabnr, bufnr, pinned)
  local meta = M.resolve(tabnr, false)
  if meta == nil then
    return
  end

  if bufnr > 0 and vim.api.nvim_buf_is_valid(bufnr) and vim.bo[bufnr].buflisted then
    for _, buf in ipairs(meta.bufs) do
      if buf.bufnr == bufnr then
        if pinned ~= nil and buf.pinned ~= pinned then
          buf.pinned = pinned
          M.rearrange_bufs(meta.bufs)
        end
        return meta
      end
    end

    local buf = { bufnr = bufnr, pinned = pinned == true } ---@type eve.builtin.tab.IBufItem
    meta.bufs[#meta.bufs + 1] = buf
    if buf.pinned then
      M.rearrange_bufs(meta.bufs)
    end
  end
  return meta
end

---@param tabnr                         integer
---@param bufnr                         integer
---@return boolean
function M.has_buf(tabnr, bufnr)
  local meta = M.resolve(tabnr, false)
  if meta == nil then
    return false
  end

  for _, buf in ipairs(meta.bufs) do
    if buf.bufnr == bufnr then
      return true
    end
  end
  return false
end

---@param bufs                          eve.builtin.tab.IBufItem[]
---@return nil
function M.rearrange_bufs(bufs)
  local n, N = 0, #bufs ---@type integer, integer
  local ordered = {} ---@type eve.builtin.tab.IBufItem[]
  for i = 1, N, 1 do
    local buf = bufs[i] ---@type eve.builtin.tab.IBufItem
    if buf.pinned then
      n = n + 1
      ordered[n] = buf
    end
  end
  for i = 1, N, 1 do
    local buf = bufs[i] ---@type eve.builtin.tab.IBufItem
    if not buf.pinned then
      n = n + 1
      ordered[n] = buf
    end
  end
  for i = 1, N, 1 do
    bufs[i] = ordered[i]
  end
end

---@param bufs                          eve.builtin.tab.IBufItem[]
---@return nil
function M.refresh_bufs(bufs)
  local k, N = 1, #bufs ---@type integer, integer
  for i = 1, N, 1 do
    local buf = bufs[i] ---@type eve.builtin.tab.IBufItem
    if vim.api.nvim_buf_is_valid(buf.bufnr) then
      bufs[k] = buf
      k = k + 1
    end
  end
  for i = N, k, -1 do
    bufs[i] = nil
  end
end

---@param tabnr                         integer
---@param force                         boolean
---@return eve.builtin.tab.TypeEnum
function M.resolve_type(tabnr, force)
  local tabtype = M.get_type(tabnr) ---@type eve.builtin.tab.TypeEnum|nil
  if tabtype ~= nil and not force then
    return tabtype
  end

  local winnrs = vim.api.nvim_tabpage_list_wins(tabnr) ---@type integer[]

  ---! Check if the diffview tab
  for _, winnr in ipairs(winnrs) do
    local bufnr = vim.api.nvim_win_get_buf(winnr) ---@type integer
    local filetype = vim.bo[bufnr].filetype ---@type string
    if filetype == eve.filetype.DIFFVIEW_FILES or filetype == eve.filetype.DIFFVIEW_FILE_HISTORY then
      tabtype = Types.DIFFVIEW ---@type eve.builtin.tab.TypeEnum
      break
    end
  end

  tabtype = tabtype or Types.NORMAL ---@type eve.builtin.tab.TypeEnum
  M.set_type(tabnr, tabtype)
  return tabtype
end

---@param bufnrs                        integer[]|nil
---@return integer[]
function M.retrieve_unreferenced_bufnrs(bufnrs)
  local tabnrs = vim.api.nvim_list_tabpages() ---@type integer[]
  local bufnr_set = {} ---@type table<integer, true>
  for _, tabnr in ipairs(tabnrs) do
    local meta = M.resolve(tabnr, false) ---@type eve.builtin.tab.IMetaData|nil
    if meta ~= nil then
      for _, buf in ipairs(meta.bufs) do
        bufnr_set[buf.bufnr] = true
      end
    end
  end

  bufnrs = bufnrs or vim.api.nvim_list_bufs() ---@type integer[]
  local bufnrs_unreferenced = {} ---@type integer[]
  for _, bufnr in ipairs(bufnrs) do
    if vim.bo[bufnr].buflisted and not bufnr_set[bufnr] then
      bufnrs_unreferenced[#bufnrs_unreferenced + 1] = bufnr
    end
  end
  return bufnrs_unreferenced
end

---@param tabnr                         integer|nil
---@return eve.builtin.tab.IBufItem|nil
---@return integer|nil
function M.retrieve_buf_sourcefile(tabnr)
  local meta = M.resolve(tabnr, false) ---@type eve.builtin.tab.IMetaData|nil
  if meta == nil then
    return
  end

  local winnr = meta.winnr_sourcefile ---@type integer|nil
  if winnr == nil or not vim.api.nvim_win_is_valid(winnr) then
    return
  end

  local bufnr = vim.api.nvim_win_get_buf(winnr) ---@type integer
  for index, buf in ipairs(meta.bufs) do
    if buf.bufnr == bufnr then
      return buf, index
    end
  end
end

---@param tabnr                         integer
---@return nil
function M.on_buf_delete(tabnr)
  if tabnr < 1 or not vim.api.nvim_tabpage_is_valid(tabnr) then
    return
  end

  local meta = M.resolve(tabnr, false) ---@type eve.builtin.tab.IMetaData|nil
  if meta == nil then
    return
  end

  M.refresh_bufs(meta.bufs)
end

---@param tabnr                         integer
---@param bufnr                         integer
---@return nil
function M.on_buf_enter(tabnr, bufnr)
  if
    tabnr < 1
    or bufnr < 1
    or not vim.api.nvim_buf_is_valid(bufnr)
    or not vim.bo[bufnr].buflisted
    or not vim.api.nvim_tabpage_is_valid(tabnr)
  then
    return
  end

  local meta = M.resolve(tabnr, false) ---@type eve.builtin.tab.IMetaData|nil
  if meta == nil then
    return
  end

  for _, buf in ipairs(meta.bufs) do
    if buf.bufnr == bufnr then
      return
    end
  end

  local buf = { bufnr = bufnr, pinned = false } ---@type eve.builtin.tab.IBufItem
  meta.bufs[#meta.bufs + 1] = buf
end

---@param tabnr                         integer
---@param bufnrs                        integer[]
---@return nil
function M.on_bufs_close(tabnr, bufnrs)
  if #bufnrs < 1 then
    return
  end

  if tabnr < 1 or not vim.api.nvim_tabpage_is_valid(tabnr) then
    return
  end

  local meta = M.resolve(tabnr, false) ---@type eve.builtin.tab.IMetaData|nil
  if meta == nil then
    return
  end

  local bufs = meta.bufs ---@type eve.builtin.tab.IBufItem[]
  local N = #bufs ---@type integer

  local k = 1 ---@type integer
  for i = 1, N, 1 do
    local buf = bufs[i] ---@type eve.builtin.tab.IBufItem
    if not vim.list_contains(bufnrs, buf.bufnr) then
      bufs[k] = buf
      k = k + 1
    end
  end
  for i = k, N, 1 do
    bufs[i] = nil
  end
end

---@parma tabnr                         integer
---@param winnr                         integer
function M.on_win_enter(tabnr, winnr)
  if tabnr < 1 or winnr < 1 then
    return
  end

  vim.schedule(function()
    if vim.api.nvim_tabpage_is_valid(tabnr) and vim.api.nvim_win_is_valid(winnr) and eve.win.is_sourcefile(winnr) then
      local meta = M.resolve(tabnr, false) ---@type eve.builtin.tab.IMetaData|nil
      if meta ~= nil then
        meta.winnr_sourcefile = winnr
      end
    end
  end)
end

return M
