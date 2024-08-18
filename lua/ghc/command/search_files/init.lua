local state = require("ghc.command.search_files.state")

---@class ghc.command.search_files
local M = {}

---@return nil
function M.focus()
  local search = state.get_search() ---@type fml.types.ui.search.ISearch
  search:focus()
end

return M
