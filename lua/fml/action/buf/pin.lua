local fn = require("eve.builtin.fn")
local state = require("eve.state")

---@class fml.action.buf
local M = {}

---@return nil
function M.toggle_pin()
  local tabnr = vim.api.nvim_get_current_tabpage() ---@type integer
  local meta_tab = state.tab.resolve(tabnr) ---@type eve.state.tab.meta.state|nil
  if meta_tab == nil then
    return
  end

  local bufid_sourcefile = meta_tab.bufid_sourcefile:snapshot() ---@type integer|nil
  if bufid_sourcefile == nil then
    return
  end

  local buf = meta_tab.bufs[bufid_sourcefile] ---@type eve.t.state.tab.buf.state
  local filepath = vim.api.nvim_buf_get_name(buf.bufnr) ---@type string

  local pinned_list = state.bookmark.pinned:snapshot() ---@type string[]
  local k = fn.find_index(pinned_list, filepath) ---@type integer|nil
  if k == nil then
    table.insert(pinned_list, filepath)
  else
    for i = k + 1, #pinned_list, 1 do
      pinned_list[k] = pinned_list[i]
      k = k + 1
    end
    pinned_list[k] = nil
  end

  meta_tab:toggle_pin(buf.bufnr)
  state.status.dirtier_tabline:mark_dirty()
end

return M
