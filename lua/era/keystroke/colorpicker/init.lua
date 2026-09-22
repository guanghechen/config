---@diagnostic disable-next-line: unused-local
local __module_name__ = "era.keystroke.colorpicker" ---@type string

---@class era.keystroke.colorpicker.__mods
local __mods = {
  Color = "era.keystroke.colorpicker.color",
  ColorPicker = "era.keystroke.colorpicker.colorpicker",
  convert = "era.keystroke.colorpicker.convert",
  mode = "era.keystroke.colorpicker.mode",
  picker = "era.keystroke.colorpicker.picker",
  UI = "era.keystroke.colorpicker.ui",
}

---@class era.keystroke.colorpicker
---@field public __mods                 era.keystroke.colorpicker.__mods
---@field public Color                  era.keystroke.colorpicker.Color
---@field public ColorPicker            era.keystroke.colorpicker.ColorPicker
---@field public convert                era.keystroke.colorpicker.convert
---@field public mode                   era.keystroke.colorpicker.mode
---@field public picker                 era.keystroke.colorpicker.picker
---@field public UI                     era.keystroke.colorpicker.UI
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
