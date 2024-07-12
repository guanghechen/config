local state = require("fml.api.state")

---@class fml.api.buf
local M = require("fml.api.buf.mod")

function M.toggle_pin_cur()
  local bufnr = vim.api.nvim_get_current_buf() ---@type integer
  local buf = state.bufs[bufnr] ---@type fml.api.state.IBufItem|nil
  if buf ~= nil then
    buf.pinned = true
    vim.cmd("redrawtabline")
  end
end
