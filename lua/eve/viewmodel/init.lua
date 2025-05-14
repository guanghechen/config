---@class eve.viewmodel.__mods
local __mods = {
  git = "eve.viewmodel.git",
}

---@class eve.viewmodel
---@field public __mods                 eve.viewmodel.__mods
---
---@field public git                    eve.viewmodel.git
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
