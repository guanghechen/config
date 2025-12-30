---@class era.m.colorpicker.__mods
local __mods = {
  Color = "era.m.colorpicker.color",
  ColorPicker = "era.m.colorpicker.colorpicker",
  convert = "era.m.colorpicker.convert",
  mode = "era.m.colorpicker.mode",
  picker = "era.m.colorpicker.picker",
  UI = "era.m.colorpicker.ui",
}

---@class era.m.colorpicker
---@field public __mods                 era.m.colorpicker.__mods
---@field public Color                  era.m.colorpicker.Color
---@field public ColorPicker            era.m.colorpicker.ColorPicker
---@field public convert                era.m.colorpicker.convert
---@field public mode                   era.m.colorpicker.mode
---@field public picker                 era.m.colorpicker.picker
---@field public UI                     era.m.colorpicker.UI
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
