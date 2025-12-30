---@class era.m.lsp.__mods
local __mods = {
  action = "era.m.lsp.action",
  diagnostic = "era.m.lsp.diagnostic",
  event = "era.m.lsp.event",
  fn = "era.m.lsp.fn",
}

---@class era.m.lsp
---@field public __mods                 era.m.lsp.__mods
---@field public action                 era.m.lsp.action
---@field public diagnostic             era.m.lsp.diagnostic
---@field public event                  era.m.lsp.event
---@field public fn                     era.m.lsp.fn
local M = setmetatable({
  __mods = __mods,
}, {
  __index = function(t, k)
    local m = __mods[k] ---@type string|nil
    if m == nil then
      return rawget(t, k)
    end
    return require(m)
  end,
})

----------------------------------------------------------------------------------------------------

---@return nil
function M.dressing()
  M.diagnostic.setup()
  vim.lsp.buf.code_action = M.action.code_action
end

return M
