---@class era.colorpicker.__mods
local __mods = {
  Color = "era.colorpicker.color",
  ColorPicker = "era.colorpicker.colorpicker",
  convert = "era.colorpicker.convert",
  mode = "era.colorpicker.mode",
  picker = "era.colorpicker.picker",
  UI = "era.colorpicker.ui",
}

---@class era.colorpicker
---@field public __mods                 era.colorpicker.__mods
---@field public Color                  era.colorpicker.Color
---@field public ColorPicker            era.colorpicker.ColorPicker
---@field public convert                era.colorpicker.convert
---@field public mode                   era.colorpicker.mode
---@field public picker                 era.colorpicker.picker
---@field public UI                     era.colorpicker.UI
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
