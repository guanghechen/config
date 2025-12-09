---@class ark.__mods
local __mods = {
  color = "ark.color",
  easing = "ark.easing",
  reporter = "ark.reporter",
}

---@class ark
---@field public __mods                 ark.__mods
---@field public color                  ark.color
---@field public easing                 ark.easing
---@field public reporter               ark.reporter
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
