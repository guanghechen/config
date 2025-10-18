---@class eve.state.__mods
local __mods = {
  git = "eve.state.git",
  maximized = "eve.state.maximized",
}

---@class eve.state
---@field public __mods                 eve.state.__mods
---
---@field public git                    eve.state.git
---@field public maximized              eve.state.maximized
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
