---@class era.image.__mods
local __mods = {
  Convert = "era.image.convert",
  doc = "era.image.doc",
  Image = "era.image.image",
  inline = "era.image.inline",
  Placement = "era.image.placement",
  state = "era.image.state",
  terminal = "era.image.terminal",
}

---@class era.image
---@field public __mods                 era.image.__mods
---@field public Convert                era.image.Convert
---@field public doc                    era.image.doc
---@field public Image                  era.image.Image
---@field public inline                 era.image.inline
---@field public Placement              era.image.Placement
---@field public state                  era.image.state
---@field public terminal               era.image.terminal
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
