---@class oxi.__mods
local __mods = {
  fn = "oxi.fn",
  fs = "oxi.fs",

  replacer = "oxi.replacer",
  string = "oxi.string",
}

---@class oxi
---@field public __mods                 oxi.__mods
---@field public fn                     oxi.fn
---@field public fs                     oxi.fs
---
---@field public replacer               oxi.replacer
---@field public string                 oxi.string
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
