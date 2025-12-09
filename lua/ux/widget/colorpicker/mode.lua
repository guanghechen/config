local convert = require("ux.widget.colorpicker.convert")

---@param r                             integer
---@param g                             integer
---@param b                             integer
---@return integer[]
local function rgb_identity(r, g, b)
  return { r, g, b }
end

---@param value                         integer[]
---@return integer, integer, integer
local function rgb_identity_reverse(value)
  return value[1], value[2], value[3]
end

---@class ux.widget.colorpicker.mode
---@field public input                  ux.widget.colorpicker.mode.input
---@field public output                 ux.widget.colorpicker.mode.output
local M = {}

---@class ux.widget.colorpicker.mode.input
M.input = {
  ---@type ux.widget.colorpicker.IInputMode
  hex = {
    name = "HEX",
    bar_name = { "R", "G", "B" },
    max = { 255, 255, 255 },
    from_rgb = rgb_identity,
    to_rgb = rgb_identity_reverse,
  },
  ---@type ux.widget.colorpicker.IInputMode
  rgb = {
    name = "RGB",
    bar_name = { "R", "G", "B" },
    max = { 255, 255, 255 },
    from_rgb = rgb_identity,
    to_rgb = rgb_identity_reverse,
  },
  ---@type ux.widget.colorpicker.IInputMode
  hsl = {
    name = "HSL",
    bar_name = { "H", "S", "L" },
    max = { 360, 100, 100 },
    from_rgb = function(r, g, b)
      local h, s, l = convert.rgb2hsl(r, g, b)
      return { h, s, l }
    end,
    to_rgb = function(value)
      return convert.hsl2rgb(value[1], value[2], value[3])
    end,
  },
  ---@type ux.widget.colorpicker.IInputMode
  hsv = {
    name = "HSV",
    bar_name = { "H", "S", "V" },
    max = { 360, 100, 100 },
    from_rgb = function(r, g, b)
      local h, s, v = convert.rgb2hsv(r, g, b)
      return { h, s, v }
    end,
    to_rgb = function(value)
      return convert.hsv2rgb(value[1], value[2], value[3])
    end,
  },
}

---@class ux.widget.colorpicker.mode.output
M.output = {
  ---@type ux.widget.colorpicker.IOutputMode
  hex = {
    name = "HEX",
    str = function(r, g, b, alpha)
      if alpha then
        return string.format("#%02x%02x%02x%02x", r, g, b, convert.round(alpha * 255 / 100))
      end
      return string.format("#%02x%02x%02x", r, g, b)
    end,
  },
  ---@type ux.widget.colorpicker.IOutputMode
  rgb = {
    name = "RGB",
    str = function(r, g, b, alpha)
      if alpha then
        return string.format("rgb(%d %d %d / %d%%)", r, g, b, alpha)
      end
      return string.format("rgb(%d,%d,%d)", r, g, b)
    end,
  },
  ---@type ux.widget.colorpicker.IOutputMode
  hsl = {
    name = "HSL",
    str = function(r, g, b, alpha)
      local h, s, l = convert.rgb2hsl(r, g, b)
      if alpha then
        return string.format("hsl(%d %d%% %d%% / %d%%)", h, s, l, alpha)
      end
      return string.format("hsl(%d,%d%%,%d%%)", h, s, l)
    end,
  },
  ---@type ux.widget.colorpicker.IOutputMode
  hsv = {
    name = "HSV",
    str = function(r, g, b, alpha)
      local h, s, v = convert.rgb2hsv(r, g, b)
      if alpha then
        return string.format("hsv(%d %d%% %d%% / %d%%)", h, s, v, alpha)
      end
      return string.format("hsv(%d,%d%%,%d%%)", h, s, v)
    end,
  },
}

return M
