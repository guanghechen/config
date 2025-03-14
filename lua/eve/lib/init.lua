---@class eve.lib.__mods
local __mods = {
  md5 = "eve.lib.md5",
}

---@class eve.lib
---@field public __mods                 eve.lib.__mods
---n
---@field public md5                    eve.lib.md5
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
