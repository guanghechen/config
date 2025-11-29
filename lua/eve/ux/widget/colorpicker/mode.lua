local convert = require("eve.ux.widget.colorpicker.convert")

---@type eve.ux.widget.colorpicker.IInputMode
local HexInput = {
  name = "HEX",
  bar_name = { "R", "G", "B" },
  max = { 255, 255, 255 },
  from_rgb = function(r, g, b)
    return { r, g, b }
  end,
  to_rgb = function(value)
    return value[1], value[2], value[3]
  end,
}

---@type eve.ux.widget.colorpicker.IInputMode
local RgbInput = {
  name = "RGB",
  bar_name = { "R", "G", "B" },
  max = { 255, 255, 255 },
  from_rgb = function(r, g, b)
    return { r, g, b }
  end,
  to_rgb = function(value)
    return value[1], value[2], value[3]
  end,
}

---@type eve.ux.widget.colorpicker.IInputMode
local HslInput = {
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
}

---@type eve.ux.widget.colorpicker.IInputMode
local HsvInput = {
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
}

---@type eve.ux.widget.colorpicker.IOutputMode
local HexOutput = {
  name = "HEX",
  str = function(r, g, b, alpha)
    if alpha then
      return string.format("#%02x%02x%02x%02x", r, g, b, convert.round(alpha * 255 / 100))
    end
    return string.format("#%02x%02x%02x", r, g, b)
  end,
}

---@type eve.ux.widget.colorpicker.IOutputMode
local RgbOutput = {
  name = "RGB",
  str = function(r, g, b, alpha)
    if alpha then
      return string.format("rgb(%d %d %d / %d%%)", r, g, b, alpha)
    end
    return string.format("rgb(%d,%d,%d)", r, g, b)
  end,
}

---@type eve.ux.widget.colorpicker.IOutputMode
local HslOutput = {
  name = "HSL",
  str = function(r, g, b, alpha)
    local h, s, l = convert.rgb2hsl(r, g, b)
    if alpha then
      return string.format("hsl(%d %d%% %d%% / %d%%)", h, s, l, alpha)
    end
    return string.format("hsl(%d,%d%%,%d%%)", h, s, l)
  end,
}

---@type eve.ux.widget.colorpicker.IOutputMode
local HsvOutput = {
  name = "HSV",
  str = function(r, g, b, alpha)
    local h, s, v = convert.rgb2hsv(r, g, b)
    if alpha then
      return string.format("hsv(%d %d%% %d%% / %d%%)", h, s, v, alpha)
    end
    return string.format("hsv(%d,%d%%,%d%%)", h, s, v)
  end,
}

---@class eve.ux.widget.colorpicker.mode
---@field public input                   eve.ux.widget.colorpicker.mode.input
---@field public output                  eve.ux.widget.colorpicker.mode.output
local M = {}

---@class eve.ux.widget.colorpicker.mode.input
M.input = {
  hex = HexInput,
  rgb = RgbInput,
  hsl = HslInput,
  hsv = HsvInput,
}

---@class eve.ux.widget.colorpicker.mode.output
M.output = {
  hex = HexOutput,
  rgb = RgbOutput,
  hsl = HslOutput,
  hsv = HsvOutput,
}

return M
