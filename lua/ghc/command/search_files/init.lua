local state = require("ghc.command.search_files.state")
local statusline = require("ghc.ui.statusline")

---@class ghc.command.search_files
local M = {}

---@return nil
function M.focus()
  local search = state.get_search() ---@type fml.types.ui.search.ISearch
  statusline.enable(statusline.cnames.search_files)
  search:focus()
end

return M
