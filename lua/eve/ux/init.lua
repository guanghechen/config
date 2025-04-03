---@class eve.ux.__mods
local __mods = {
  Nvimbar = "eve.ux.nvimbar",
}

---@class eve.ux
---@field public __mods                 eve.ux.__mods
---
---@field public Nvimbar                eve.ux.Nvimbar
local M = setmetatable({ __mods = __mods }, {
  __index = function(t, k)
    local m = __mods[k] ---@type string|nil
    if m == nil then
      return rawget(t, k)
    end
    return require(m)
  end,
})

return M
