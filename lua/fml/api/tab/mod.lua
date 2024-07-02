local state = require("fml.api.state")

---@class fml.api.tab
local M = {}

---@return integer|nil
function M.internal_back()
  while true do
    local present = state.tab_history:present() ---@type integer|nil
    if present == nil or vim.api.nvim_tabpage_is_valid(present) then
      return present
    else
      state.tab_history:back(1)
    end
  end
end

return M
