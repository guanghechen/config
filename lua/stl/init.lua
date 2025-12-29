---@class stl.__mods
local __mods = {
  env = "stl.env",
}

---@class stl
---@field public __mods                 stl.__mods
---@field public env                    stl.env
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
