local state = require("fml.api.state")

---@class fml.api.buf
local M = {}

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

---@param bufnr                         integer
---@return boolean
function M.is_visible(bufnr)
  local winnrs = vim.api.nvim_tabpage_list_wins(0) ---@type integer[]
  return eve.array.some(winnrs, function(winnr)
    local win_bufnr = vim.api.nvim_win_get_buf(winnr) ---@type integer
    return win_bufnr == bufnr
  end)
end

---@return nil
function M.toggle_pin_cur()
  local bufnr = vim.api.nvim_get_current_buf() ---@type integer
  local buf = state.bufs[bufnr] ---@type fml.types.api.state.IBufItem|nil
  if buf ~= nil then
    local pinned = buf.pinned ---@type boolean
    buf.pinned = not pinned
    vim.cmd("redrawtabline")
  end
end

return M
