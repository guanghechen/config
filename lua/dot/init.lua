---@class dot.__mods
local __mods = {
  env = "dot.env",
  icon = "dot.icon",
  var = "dot.var",
}

---@class dot
---@field public __mods                 dot.__mods
---@field public env                    dot.env
---@field public icon                   dot.icon
---@field public var                    dot.var
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
