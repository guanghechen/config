---@class ghc.action.avante
local M = {}

---@return nil
function M.ask()
  local tabnr = vim.api.nvim_get_current_tabpage() ---@type integer
  eve.tab.focus_win_sourcefile(tabnr)
  require("avante.api").ask()
end

---@return nil
function M.edit()
  require("avante.api").edit()
end

---@return nil
function M.refresh()
  require("avante.api").refresh()
end

return M
