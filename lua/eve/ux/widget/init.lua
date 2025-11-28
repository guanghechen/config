---@class eve.ux.widget.__mods
local __mods = {
  Notepad = "eve.ux.widget.notepad",
  Terminal = "eve.ux.widget.terminal",
}

---@type eve.ux.widget.colorpicker.ColorPicker|nil
local _colorpicker = nil

---@class eve.ux.widget
---@field public __mods                 eve.ux.widget.__mods
---
---@field public ColorPicker            eve.ux.widget.colorpicker.ColorPicker
---@field public Notepad                eve.ux.widget.Notepad
---@field public Terminal               eve.ux.widget.Terminal
local M = setmetatable({
  __mods = __mods,
}, {
  __index = function(t, k)
    if k == "ColorPicker" then
      if _colorpicker == nil then
        _colorpicker = require("eve.ux.widget.colorpicker").new()
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
