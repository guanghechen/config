---@class ux.widget.__mods
local __mods = {
  ai = "ux.widget.ai",
  Notepad = "ux.widget.notepad",
  Terminal = "ux.widget.terminal",
}

---@type ux.widget.colorpicker.ColorPicker|nil
local _colorpicker = nil

---@class ux.widget
---@field public __mods                 ux.widget.__mods
---
---@field public ai                     ux.widget.ai
---@field public ColorPicker            ux.widget.colorpicker.ColorPicker
---@field public Notepad                ux.widget.Notepad
---@field public Terminal               ux.widget.Terminal
local M = setmetatable({
  __mods = __mods,
}, {
  __index = function(t, k)
    if k == "ColorPicker" then
      if _colorpicker == nil then
        _colorpicker = require("ux.widget.colorpicker").new()
      end
      return _colorpicker
    end
    local m = __mods[k] ---@type string|nil
    if m == nil then
      return rawget(t, k)
    end
    return require(m)
  end,
})

return M
