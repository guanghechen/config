local state = require("ghc.command.find_files.state")

---@class ghc.command.find_files
local M = {}

---@return nil
function M.focus()
  local select = state.get_select() ---@type fml.types.ui.select.ISelect
  select:focus()
end

return M
