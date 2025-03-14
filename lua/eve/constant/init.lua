---@class eve.constant.__mods
local __mods = {
  setting = "eve.constant.setting",
}

---@class eve.constant
---@field public __mods                 eve.constant.__mods
---
---@field public setting                eve.constant.setting
---@field public varname                eve.constant.varname
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
