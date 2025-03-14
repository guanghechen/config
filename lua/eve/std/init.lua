---@class eve.std.__mods
local __mods = {
  im = "eve.std.im",
  nvim = "eve.std.nvim",
}

---@class eve.std
---@field public __mods                 eve.std.__mods
---
---@field public im                     eve.std.im
---@field public nvim                   eve.std.nvim
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
