---@class dot.tab.IBufItem
---@field public bufnr                  integer
---@field public pinned                 boolean

---@class dot.tab.IMeta
---@field public bufs                   dot.tab.IBufItem[]
---@field public winnr_fixed            stl.c.Observable
---@field public winnr_float            stl.c.Observable
---@field public winnr_sourcefile       stl.c.Observable
---@field public tabtype                stl.e.TabTypeEnum

local meta_map = {} ---@type table<integer, dot.tab.IMeta>

-- Consecutive `TabClosed` events share one scheduled refresh while retaining every cleanup candidate.
local bufnrs_pending_tab_close = {} ---@type integer[]
local bufnr_pending_tab_close_set = {} ---@type table<integer, true>
local tab_close_refresh_scheduled = false ---@type boolean

---@class dot.tab
local M = {}

----------------------------------------------------------------------------------------------------

---@param tabnr                         integer
---@return nil
function M.focus_win_fixed(tabnr)
  local winnr_fixed = M.retrieve_winnr_fixed(tabnr) ---@type integer|nil
  if winnr_fixed ~= nil then
    vim.api.nvim_tabpage_set_win(tabnr, winnr_fixed)
  end
end

---@param tabnr                         integer
---@return nil
function M.focus_win_float(tabnr)
  local winnr_float = M.retrieve_winnr_float(tabnr) ---@type integer|nil
  if winnr_float ~= nil then
    vim.api.nvim_tabpage_set_win(tabnr, winnr_float)
  end
end

---@param tabnr                         integer
---@return nil
function M.focus_win_sourcefile(tabnr)
  local winnr_sourcefile = M.retrieve_winnr_sourcefile(tabnr) ---@type integer|nil
  if winnr_sourcefile ~= nil then
    vim.api.nvim_tabpage_set_win(tabnr, winnr_sourcefile)
  end
end

---@param bufnrs                        ?integer[]
---@return integer[]
function M.retrieve_unreferenced_bufnrs(bufnrs)
  local tabnrs = vim.api.nvim_list_tabpages() ---@type integer[]
  local bufnr_set = {} ---@type table<integer, true>
  for _, tabnr in ipairs(tabnrs) do
    local meta = M.resolve(tabnr, false) ---@type dot.tab.IMeta|nil
    if meta ~= nil then
      for _, buf in ipairs(meta.bufs) do
        bufnr_set[buf.bufnr] = true
      end
    end
  end

  bufnrs = bufnrs or vim.api.nvim_list_bufs() ---@type integer[]
  local bufnrs_unreferenced = {} ---@type integer[]
  for _, bufnr in ipairs(bufnrs) do
    if
      vim.api.nvim_buf_is_valid(bufnr)
      and vim.api.nvim_get_option_value("buflisted", { buf = bufnr })
      and not bufnr_set[bufnr]
    then
      bufnrs_unreferenced[#bufnrs_unreferenced + 1] = bufnr
    end
  end
  return bufnrs_unreferenced
end

---@param tabnr                         ?integer
---@return dot.tab.IBufItem|nil
---@return integer|nil
function M.retrieve_buf_sourcefile(tabnr)
  local meta = M.resolve(tabnr, false) ---@type dot.tab.IMeta|nil
  if meta == nil then
    return
  end

  local winnr = meta.winnr_sourcefile:snapshot() ---@type integer
  if winnr < 1 or not vim.api.nvim_win_is_valid(winnr) then
    return
  end

  local bufnr = vim.api.nvim_win_get_buf(winnr) ---@type integer
  for index, buf in ipairs(meta.bufs) do
    if buf.bufnr == bufnr then
      return buf, index
    end
  end
end

---@param tabnr                         ?integer
---@return integer|nil
function M.retrieve_bufnr_sourcefile(tabnr)
  local winnr_sourcefile = M.retrieve_winnr_sourcefile(tabnr) ---@type integer|nil
  if winnr_sourcefile == nil or not vim.api.nvim_win_is_valid(winnr_sourcefile) then
    return
  end
  return vim.api.nvim_win_get_buf(winnr_sourcefile) ---@type integer
end

---@param tabnr                         ?integer
---@return integer|nil
function M.retrieve_winnr_fixed(tabnr)
  local meta = M.resolve(tabnr, false) ---@type dot.tab.IMeta|nil
  return meta ~= nil and meta.winnr_fixed:snapshot() or nil ---@type integer|nil
end

---@param tabnr                         ?integer
---@return integer|nil
function M.retrieve_winnr_float(tabnr)
  local meta = M.resolve(tabnr, false) ---@type dot.tab.IMeta|nil
  return meta ~= nil and meta.winnr_float:snapshot() or nil ---@type integer|nil
end

---@param tabnr                         ?integer
---@return integer|nil
function M.retrieve_winnr_sourcefile(tabnr)
  if tabnr == nil then
    return nil
  end

  local meta = M.resolve(tabnr, false) ---@type dot.tab.IMeta|nil
  if meta == nil then
    meta = M.resolve(tabnr, true) ---@type dot.tab.IMeta|nil
  end
  if meta == nil then
    return nil
  end

  local o_winnr_sourcefile = meta.winnr_sourcefile ---@type stl.c.Observable
  local winnr_sourcefile = o_winnr_sourcefile:snapshot() ---@type integer|nil

  if winnr_sourcefile == nil or not dot.win.is_sourcefile(winnr_sourcefile) then
    local winnrs = vim.api.nvim_tabpage_list_wins(tabnr) ---@type integer[]
    for _, winnr in ipairs(winnrs) do
      if dot.win.is_sourcefile(winnr) then
        winnr_sourcefile = winnr
        o_winnr_sourcefile:next(winnr)
        return winnr_sourcefile
      end
    end
    return nil
  end
  return winnr_sourcefile
end

----------------------------------------------------------------------------------------------------

---@param tabnr                         integer
---@param bufnr                         integer
---@param pinned                        ?boolean
---@return dot.tab.IMeta|nil
function M.add_buf(tabnr, bufnr, pinned)
  if
    bufnr < 1
    or not vim.api.nvim_buf_is_valid(bufnr)
    or not vim.api.nvim_get_option_value("buflisted", { buf = bufnr })
  then
    return
  end

  local meta = M.resolve(tabnr, false)
  if meta == nil then
    return
  end

  for _, buf in ipairs(meta.bufs) do
    if buf.bufnr == bufnr then
      if pinned ~= nil and buf.pinned ~= pinned then
        buf.pinned = pinned
        M.rearrange_bufs(meta.bufs)
      end
      return meta
    end
  end

  local buf = { bufnr = bufnr, pinned = pinned == true } ---@type dot.tab.IBufItem
  meta.bufs[#meta.bufs + 1] = buf
  if buf.pinned then
    M.rearrange_bufs(meta.bufs)
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

---@param bufs                          dot.tab.IBufItem[]
---@return nil
function M.rearrange_bufs(bufs)
  local n, N = 0, #bufs ---@type integer, integer
  local ordered = {} ---@type dot.tab.IBufItem[]
  for i = 1, N, 1 do
    local buf = bufs[i] ---@type dot.tab.IBufItem
    if buf.pinned then
      n = n + 1
      ordered[n] = buf
    end
  end
  for i = 1, N, 1 do
    local buf = bufs[i] ---@type dot.tab.IBufItem
    if not buf.pinned then
      n = n + 1
      ordered[n] = buf
    end
  end
  for i = 1, N, 1 do
    bufs[i] = ordered[i]
  end
end

--- Rebuild all live tab metadata, then delete unreferenced buffers from the optional candidate set.
--- Without candidates, deletion applies to every Neovim buffer.
---@param bufnrs                        ?integer[]
---@return nil
function M.refresh(bufnrs)
  local tabnrs = vim.api.nvim_list_tabpages() ---@type integer[]
  for _, tabnr in ipairs(tabnrs) do
    M.resolve(tabnr, true)
  end

  local bufnrs_unreferenced = M.retrieve_unreferenced_bufnrs(bufnrs) ---@type integer[]
  for _, bufnr in ipairs(bufnrs_unreferenced) do
    -- A tab close must never discard unsaved edits owned only by that tab.
    local modified = vim.api.nvim_get_option_value("modified", { buf = bufnr }) ---@type boolean
    if not modified then
      vim.api.nvim_buf_delete(bufnr, { force = true })
    end
  end
end

---@param bufs                          dot.tab.IBufItem[]
---@return nil
function M.refresh_bufs(bufs)
  local k, N = 1, #bufs ---@type integer, integer
  for i = 1, N, 1 do
    local buf = bufs[i] ---@type dot.tab.IBufItem
    if vim.api.nvim_buf_is_valid(buf.bufnr) then
      bufs[k] = buf
      k = k + 1
    end
  end

  for index = N, k, -1 do
    bufs[index] = nil
  end
end

---@param tabnr                         ?integer
---@param force                         boolean
---@return dot.tab.IMeta|nil
function M.resolve(tabnr, force)
  if tabnr == nil or tabnr < 1 or not vim.api.nvim_tabpage_is_valid(tabnr) then
    return nil
  end

  local meta = meta_map[tabnr] ---@type dot.tab.IMeta|nil
  if meta ~= nil and not force then
    return meta
  end

  local bufs = {} ---@type dot.tab.IBufItem[]
  local bufnr_set = {} ---@type table<integer, boolean>
  if meta ~= nil then
    for _, buf in ipairs(meta.bufs) do
      ---@cast buf                      dot.tab.IBufItem
      local bufnr = buf.bufnr ---@type integer
      local pinned = buf.pinned ---@type boolean
      if
        not bufnr_set[bufnr]
        and vim.api.nvim_buf_is_valid(bufnr)
        and vim.api.nvim_get_option_value("buflisted", { buf = bufnr })
      then
        bufnr_set[bufnr] = true
        bufs[#bufs + 1] = { bufnr = bufnr, pinned = pinned }
      end
    end
  end

  local winnrs = vim.api.nvim_tabpage_list_wins(tabnr) ---@type integer[]
  for _, winnr in ipairs(winnrs) do
    local bufnr = vim.api.nvim_win_get_buf(winnr) ---@type integer
    if vim.api.nvim_get_option_value("buflisted", { buf = bufnr }) and not bufnr_set[bufnr] then
      bufnr_set[bufnr] = true
      bufs[#bufs + 1] = { bufnr = bufnr, pinned = false }
    end
  end

  local tabtype = vim.t[tabnr].tabtype or stl.e.TabTypeEnum.NORMAL ---@type stl.e.TabTypeEnum

  local winnr = vim.api.nvim_tabpage_get_win(tabnr) ---@type integer
  local winnr_fixed = stl.c.Observable.from_value(stl.nvim.win.is_fixed(winnr) and winnr or 0) ---@type stl.c.Observable
  local winnr_float = stl.c.Observable.from_value(stl.nvim.win.is_float(winnr) and winnr or 0) ---@type stl.c.Observable
  local winnr_sourcefile = stl.c.Observable.from_value(dot.win.is_sourcefile(winnr) and winnr or 0) ---@type stl.c.Observable

  ---@type dot.tab.IMeta
  meta = {
    bufs = bufs,
    winnr_fixed = winnr_fixed,
    winnr_float = winnr_float,
    winnr_sourcefile = winnr_sourcefile,
    tabtype = tabtype,
  }
  meta_map[tabnr] = meta
  return meta
end

--- Remove a globally deleted buffer from every tab's metadata.
---@param bufnr                         integer
---@return nil
function M.on_buf_delete(bufnr)
  if bufnr < 1 then
    return
  end

  local removed = false
  for _, meta in pairs(meta_map) do
    local bufs = meta.bufs ---@type dot.tab.IBufItem[]
    local k, N = 1, #bufs ---@type integer, integer
    for i = 1, N, 1 do
      local buf = bufs[i] ---@type dot.tab.IBufItem
      if buf.bufnr == bufnr then
        removed = true
      else
        bufs[k] = buf
        k = k + 1
      end
    end
    for i = N, k, -1 do
      bufs[i] = nil
    end
  end

  if removed then
    dot.state.status.dirtier_tabline:mark_dirty()
  end
end

---@param tabnr                         integer
---@param bufnr                         integer
---@return nil
function M.on_buf_enter(tabnr, bufnr)
  if tabnr < 1 or bufnr < 1 or not vim.api.nvim_get_option_value("buflisted", { buf = bufnr }) then
    return
  end

  local meta = M.resolve(tabnr, false) ---@type dot.tab.IMeta|nil
  if meta == nil then
    return
  end

  for _, buf in ipairs(meta.bufs) do
    if buf.bufnr == bufnr then
      return
    end
  end

  local buf = { bufnr = bufnr, pinned = false } ---@type dot.tab.IBufItem
  table.insert(meta.bufs, buf)
end

--- Detach buffer references from one tab without deleting the underlying buffers.
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

  local meta = M.resolve(tabnr, false) ---@type dot.tab.IMeta|nil
  if meta == nil then
    return
  end

  local bufs = meta.bufs ---@type dot.tab.IBufItem[]
  local k, N = 1, #bufs ---@type integer, integer
  for i = 1, N, 1 do
    local buf = bufs[i] ---@type dot.tab.IBufItem
    if not vim.list_contains(bufnrs, buf.bufnr) and vim.api.nvim_buf_is_valid(buf.bufnr) then
      bufs[k] = buf
      k = k + 1
    end
  end
  -- `k - 1` is the number kept, so `k <= N` means at least one entry was dropped.
  if k <= N then
    for i = N, k, -1 do
      bufs[i] = nil
    end
    dot.state.status.dirtier_tabline:mark_dirty()
  end
end

---@return nil
function M.on_close()
  -- `TabClosed` reports the closing tab's *number*, while `meta_map` is keyed by tabpage handle,
  -- and by the time the event fires the handle is gone so the two cannot be mapped. Drop whatever
  -- no longer resolves instead: that is exactly the set of closed tabs.
  for tabnr, meta in pairs(meta_map) do
    if not vim.api.nvim_tabpage_is_valid(tabnr) then
      for _, buf in ipairs(meta.bufs) do
        if not bufnr_pending_tab_close_set[buf.bufnr] then
          bufnr_pending_tab_close_set[buf.bufnr] = true
          bufnrs_pending_tab_close[#bufnrs_pending_tab_close + 1] = buf.bufnr
        end
      end

      meta_map[tabnr] = nil
      meta.winnr_fixed:dispose()
      meta.winnr_float:dispose()
      meta.winnr_sourcefile:dispose()
    end
  end

  if tab_close_refresh_scheduled then
    return
  end
  tab_close_refresh_scheduled = true

  -- Defer buffer deletion so BufDelete autocmds are not suppressed by the non-nested TabClosed event.
  vim.schedule(function()
    local bufnrs = bufnrs_pending_tab_close
    bufnrs_pending_tab_close = {}
    bufnr_pending_tab_close_set = {}
    tab_close_refresh_scheduled = false
    M.refresh(bufnrs)
  end)
end

return M
