local session = require("ghc.context.session")

---@class ghc.command.buf
local M = {}

---@return nil
function M.toggle_pin_cur()
  local bufnr = vim.api.nvim_get_current_buf() ---@type integer
  local buf = fml.api.state.bufs[bufnr] ---@type fml.types.api.state.IBufItem|nil
  if buf ~= nil then
    local pinned = buf.pinned ---@type boolean
    local filepath = buf.filepath ---@type string

    local pinned_filepaths = session.pinned_filepaths:snapshot() ---@type table<string, boolean>
    pinned_filepaths[filepath] = not pinned

    buf.pinned = not pinned
    vim.cmd.redrawtabline()
  end
end

return M
