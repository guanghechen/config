---@diagnostic disable-next-line: unused-local
local __module_name__ = "era.keystroke.colorpicker.mode" ---@type string

local S = era.keystroke.colorpicker

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

---@class era.keystroke.colorpicker.mode
---@field public input                  era.keystroke.colorpicker.mode.input
---@field public output                 era.keystroke.colorpicker.mode.output
local M = {}

---@class era.keystroke.colorpicker.mode.input
M.input = {
  ---@type era.keystroke.colorpicker.IInputMode
  hex = {
    name = "HEX",
    bar_name = { "R", "G", "B" },
    max = { 255, 255, 255 },
    from_rgb = rgb_identity,
    to_rgb = rgb_identity_reverse,
  },
  ---@type era.keystroke.colorpicker.IInputMode
  rgb = {
    name = "RGB",
    bar_name = { "R", "G", "B" },
    max = { 255, 255, 255 },
    from_rgb = rgb_identity,
    to_rgb = rgb_identity_reverse,
  },
  ---@type era.keystroke.colorpicker.IInputMode
  hsl = {
    name = "HSL",
    bar_name = { "H", "S", "L" },
    max = { 360, 100, 100 },
    from_rgb = function(r, g, b)
      local h, s, l = S.convert.rgb2hsl(r, g, b)
      return { h, s, l }
    end,
    to_rgb = function(value)
      return S.convert.hsl2rgb(value[1], value[2], value[3])
    end,
  },
  ---@type era.keystroke.colorpicker.IInputMode
  hsv = {
    name = "HSV",
    bar_name = { "H", "S", "V" },
    max = { 360, 100, 100 },
    from_rgb = function(r, g, b)
      local h, s, v = S.convert.rgb2hsv(r, g, b)
      return { h, s, v }
    end,
    to_rgb = function(value)
      return S.convert.hsv2rgb(value[1], value[2], value[3])
    end,
  },
}

---@class era.keystroke.colorpicker.mode.output
M.output = {
  ---@type era.keystroke.colorpicker.IOutputMode
  hex = {
    name = "HEX",
    str = function(r, g, b, alpha)
      if alpha then
        return string.format("#%02x%02x%02x%02x", r, g, b, S.convert.round(alpha * 255 / 100))
      end
      return string.format("#%02x%02x%02x", r, g, b)
    end,
  },
  ---@type era.keystroke.colorpicker.IOutputMode
  rgb = {
    name = "RGB",
    str = function(r, g, b, alpha)
      if alpha then
        return string.format("rgb(%d %d %d / %d%%)", r, g, b, alpha)
      end
      return string.format("rgb(%d,%d,%d)", r, g, b)
    end,
  },
  ---@type era.keystroke.colorpicker.IOutputMode
  hsl = {
    name = "HSL",
    str = function(r, g, b, alpha)
      local h, s, l = S.convert.rgb2hsl(r, g, b)
      if alpha then
        return string.format("hsl(%d %d%% %d%% / %d%%)", h, s, l, alpha)
      end
      return string.format("hsl(%d,%d%%,%d%%)", h, s, l)
    end,
  },
  ---@type era.keystroke.colorpicker.IOutputMode
  hsv = {
    name = "HSV",
    str = function(r, g, b, alpha)
      local h, s, v = S.convert.rgb2hsv(r, g, b)
      if alpha then
        return string.format("hsv(%d %d%% %d%% / %d%%)", h, s, v, alpha)
      end
      return string.format("hsv(%d,%d%%,%d%%)", h, s, v)
    end,
  },
}

return M
