---@class eve.fn.__mods
local __mods = {
  rename = "eve.fn.rename",
}

---@class eve.fn
---@field public __mods                 eve.fn.__mods
---
---@field public rename                 eve.fn.rename
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

return M
