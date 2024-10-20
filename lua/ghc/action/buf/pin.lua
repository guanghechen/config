---@class ghc.action.buf
local M = require("ghc.action.buf.mod")

---@return nil
function M.toggle_pin_cur()
  local bufnr = vim.api.nvim_get_current_buf() ---@type integer
  local buf = eve.context.state.bufs[bufnr] ---@type t.eve.context.state.buf.IItem|nil
  if buf ~= nil then
    local pinned = buf.pinned ---@type boolean
    local filepath = buf.filepath ---@type string

    local pinned_list = eve.context.state.bookmark.pinned:snapshot() ---@type string[]
    eve.array.toggle_inline(pinned_list, filepath)

    buf.pinned = not pinned
    vim.cmd.redrawtabline()
  end
end
