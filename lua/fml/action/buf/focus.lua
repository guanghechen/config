local __module_name__ = "fml.action.buf" ---@type string

---@class fml.action.buf
local M = {}

---@param bufnr                         integer the stable unique number of the buffer
---@return nil
function M.open(bufnr)
  local tabnr = vim.api.nvim_get_current_tabpage() ---@type integer
  local winnr_sourcefile = eve.state.tab.get_winnr_sourcefile(tabnr) ---@type integer|nil
  if winnr_sourcefile ~= nil then
    vim.api.nvim_win_set_buf(winnr_sourcefile, bufnr)
  end
end

---@param bufid                         integer the index of buffer list
---@return nil
function M.focus(bufid)
  local tabnr = vim.api.nvim_get_current_tabpage() ---@type integer
  local meta_tab = eve.state.tab.resolve(tabnr) ---@type eve.state.tab.meta.state|nil
  if meta_tab == nil then
    eve.reporter.error({
      from = __module_name__,
      subject = "focus",
      message = "Cannot resolve the meta for the current tab.",
      details = { tabnr = tabnr, bufid = bufid },
    })
    return
  end

  local bufs = meta_tab.bufs ---@type eve.state.tab.buf.state[]
  local bufid_next = eve.fn.navigate_circular(0, bufid, #bufs) ---@type integer
  M.open(bufs[bufid_next].bufnr)
end

---@param step                          integer|nil
---@return nil
function M.focus_left(step)
  local tabnr = vim.api.nvim_get_current_tabpage() ---@type integer
  local meta_tab = eve.state.tab.resolve(tabnr) ---@type eve.state.tab.meta.state|nil
  if meta_tab == nil then
    eve.reporter.error({
      from = __module_name__,
      subject = "focus_left",
      message = "Cannot resolve the meta for the current tab.",
      details = { tabnr = tabnr },
    })
    return
  end

  local bufid_sourcefile = meta_tab.bufid_sourcefile:snapshot() ---@type integer|nil
  if bufid_sourcefile == nil then
    return
  end

  step = math.max(1, step or vim.v.count1 or 1)

  local bufs = meta_tab.bufs ---@type eve.state.tab.buf.state[]
  local bufid_next = eve.fn.navigate_circular(bufid_sourcefile, -step, #bufs) ---@type integer
  M.open(bufs[bufid_next].bufnr)
end

---@param step                          integer|nil
---@return nil
function M.focus_right(step)
  local tabnr = vim.api.nvim_get_current_tabpage() ---@type integer
  local meta_tab = eve.state.tab.resolve(tabnr) ---@type eve.state.tab.meta.state|nil
  if meta_tab == nil then
    eve.reporter.error({
      from = __module_name__,
      subject = "focus_right",
      message = "Cannot resolve the meta for the current tab.",
      details = { tabnr = tabnr },
    })
    return
  end

  local bufid_sourcefile = meta_tab.bufid_sourcefile:snapshot() ---@type integer|nil
  if bufid_sourcefile == nil then
    return
  end

  step = math.max(1, step or vim.v.count1 or 1)
  local bufs = meta_tab.bufs ---@type eve.state.tab.buf.state[]
  local bufid_next = eve.fn.navigate_circular(bufid_sourcefile, step, #bufs) ---@type integer
  M.open(bufs[bufid_next].bufnr)
end

return M
