---@class dot.ux.widget.__mods
local __mods = {
  ai = "dot.ux.widget.ai",
  Notepad = "dot.ux.widget.notepad",
  Terminal = "dot.ux.widget.terminal",
}

---@type dot.ux.widget.colorpicker.ColorPicker|nil
local _colorpicker = nil

---@class dot.ux.widget
---@field public __mods                 dot.ux.widget.__mods
---
---@field public ai                     dot.ux.widget.ai
---@field public ColorPicker            dot.ux.widget.colorpicker.ColorPicker
---@field public Notepad                dot.ux.widget.Notepad
---@field public Terminal               dot.ux.widget.Terminal
local M = setmetatable({
  __mods = __mods,
}, {
  __index = function(t, k)
    if k == "ColorPicker" then
      if _colorpicker == nil then
        _colorpicker = require("dot.ux.widget.colorpicker").new()
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
