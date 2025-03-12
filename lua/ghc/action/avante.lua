---@class ghc.action.avante
local M = {}

---@return nil
function M.ask()
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
