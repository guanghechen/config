---@class eve.std.__mods
local __mods = {
  color = "eve.std..lib.color",
  md5 = "eve.std.lib.md5",
}

---@class eve.std
---@field public __mods                 eve.std.__mods
---
---@field public color                  eve.std.lib.color
---@field public md5                    eve.std.lib.md5
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
