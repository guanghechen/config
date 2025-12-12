---@class fml.action.buf
local M = {}

---@return nil
function M.toggle_pin()
  local tabnr = vim.api.nvim_get_current_tabpage() ---@type integer
  local meta = era.tab.resolve(tabnr, false) ---@type era.tab.IMeta|nil
  if meta == nil then
    return
  end

  local _, bufid_sourcefile = era.tab.retrieve_buf_sourcefile(tabnr) ---@type era.tab.IBufItem|nil, integer|nil
  if bufid_sourcefile == nil then
    return
  end

  local buf = meta.bufs[bufid_sourcefile] ---@type era.tab.IBufItem
  local filepath = vim.api.nvim_buf_get_name(buf.bufnr) ---@type string

  local pinned_list = eve.context.bookmark.pinned:snapshot() ---@type string[]
  local k = ark.table.find_index(pinned_list, filepath) ---@type integer|nil
  if k == nil then
    table.insert(pinned_list, filepath)
  else
    for i = k + 1, #pinned_list, 1 do
      pinned_list[k] = pinned_list[i]
      k = k + 1
    end
    pinned_list[k] = nil
  end

  era.tab.add_buf(tabnr, buf.bufnr, not buf.pinned)
  era.state.status.dirtier_tabline:mark_dirty()
end

return M
