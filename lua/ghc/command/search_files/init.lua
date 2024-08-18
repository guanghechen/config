local state = require("ghc.command.search_files.state")
local statusline = require("ghc.ui.statusline")

---@class ghc.command.search_files
local M = {}

---@return nil
function M.focus()
  state.dirpath:next(vim.fn.expand("%:p:h"))
  local search = state.get_search() ---@type fml.types.ui.search.ISearch
  statusline.enable(statusline.cnames.search_files)
  search:focus()
end

return M
