---@class era.m.toggle.__mods
local __mods = {
  list = "era.m.toggle.list",
  theme = "era.m.toggle.theme",
}

---@class era.m.toggle
---@field public __mods                 era.m.toggle.__mods
---@field public list                   era.m.toggle.list
---@field public theme                  era.m.toggle.theme
local M = setmetatable({
  __mods = __mods,
}, {
  __index = function(t, k)
    local mod = __mods[k] ---@type string|nil
    if mod == nil then
      return rawget(t, k)
    end
    return require(mod)
  end,
})

return M
