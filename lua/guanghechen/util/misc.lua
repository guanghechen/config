local function noop(...) end

---@class guanghechen.util.misc
local M = {}

---@return nil
function M.noop(...) end

---@type guanghechen.types.IUnsubscribable
M.noop_unsubscribable = {
  unsubscribe = noop,
}

return M
