---@class stl.os.__mods
local __mods = {
  fs = "stl.os.fs",
  path = "stl.os.path",
}

---@class stl.os
---@field public __mods                 stl.os.__mods
---@field public fs                     stl.os.fs
---@field public path                   stl.os.path
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
