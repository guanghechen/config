local __module_name__ = "fml.action.buf" ---@type string

local state = require("eve.state")

---@class fml.action.buf
local M = {}

---@param step                          integer|nil
---@return nil
function M.swap_left(step)
  local tabnr = vim.api.nvim_get_current_tabpage() ---@type integer
  local meta_tab = state.tab.resolve(tabnr) ---@type eve.state.tab.meta.state|nil
  if meta_tab == nil then
    eve.reporter.error({
      from = __module_name__,
      subject = "swap_left",
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
  local bufs = meta_tab.bufs ---@type eve.t.state.tab.buf.state[]
  local bufid_next = eve.std.fn.navigate_circular(bufid_sourcefile, -step, #bufs) ---@type integer
  if bufid_sourcefile == bufid_next then
    return
  end

  local buf_sourcefile = bufs[bufid_sourcefile] ---@type eve.t.state.tab.buf.state
  local buf_next = bufs[bufid_next] ---@type eve.t.state.tab.buf.state

  ---! Don't swap the two buffers if their's pinned status not equal.
  if buf_sourcefile.pinned ~= buf_next.pinned then
    return
  end

  meta_tab.bufs[bufid_next] = buf_sourcefile
  meta_tab.bufs[bufid_sourcefile] = buf_next
  state.status.dirtier_statusline:mark_dirty()
  state.status.dirtier_tabline:mark_dirty()
end

---@param step                          integer|nil
---@return nil
function M.swap_right(step)
  local tabnr = vim.api.nvim_get_current_tabpage() ---@type integer
  local meta_tab = state.tab.resolve(tabnr) ---@type eve.state.tab.meta.state|nil
  if meta_tab == nil then
    eve.reporter.error({
      from = __module_name__,
      subject = "swap_right",
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
  local bufs = meta_tab.bufs ---@type eve.t.state.tab.buf.state[]
  local bufid_next = eve.std.fn.navigate_circular(bufid_sourcefile, step, #bufs) ---@type integer
  if bufid_sourcefile == bufid_next then
    return
  end

  local buf_sourcefile = bufs[bufid_sourcefile] ---@type eve.t.state.tab.buf.state
  local buf_next = bufs[bufid_next] ---@type eve.t.state.tab.buf.state

  ---! Don't swap the two buffers if their's pinned status not equal.
  if buf_sourcefile.pinned ~= buf_next.pinned then
    return
  end

  meta_tab.bufs[bufid_next] = buf_sourcefile
  meta_tab.bufs[bufid_sourcefile] = buf_next
  state.status.dirtier_statusline:mark_dirty()
  state.status.dirtier_tabline:mark_dirty()
end

return M
