local convert = require("eve.ux.widget.colorpicker.convert")
local mode = require("eve.ux.widget.colorpicker.mode")

local INPUTS = { mode.input.hex, mode.input.rgb, mode.input.hsl, mode.input.hsv }
local OUTPUTS = { mode.output.hex, mode.output.rgb, mode.output.hsl, mode.output.hsv }

---@class eve.ux.widget.colorpicker.Color
---@field private _value                 integer[]
---@field private _alpha                 integer|nil
---@field private _show_alpha            boolean
---@field private _input_idx             integer
---@field private _output_idx            integer
local M = {}
M.__index = M

---@return eve.ux.widget.colorpicker.Color
function M.new()
  local self = setmetatable({}, M)
  self._value = { 0, 0, 0 }
  self._alpha = nil
  self._show_alpha = false
  self._input_idx = 1
  self._output_idx = 1
  return self
end

---@return eve.ux.widget.colorpicker.IInputMode
function M:input()
  return INPUTS[self._input_idx]
end

---@return eve.ux.widget.colorpicker.IOutputMode
function M:output()
  return OUTPUTS[self._output_idx]
end

---@return nil
function M:cycle_input()
  local r, g, b = self:get_rgb()
  self._input_idx = self._input_idx >= #INPUTS and 1 or self._input_idx + 1
  self:set_rgb(r, g, b)
end

---@return nil
function M:cycle_input_reverse()
  local r, g, b = self:get_rgb()
  self._input_idx = self._input_idx <= 1 and #INPUTS or self._input_idx - 1
  self:set_rgb(r, g, b)
end

---@return nil
function M:cycle_output()
  self._output_idx = self._output_idx >= #OUTPUTS and 1 or self._output_idx + 1
end

---@return nil
function M:cycle_output_reverse()
  self._output_idx = self._output_idx <= 1 and #OUTPUTS or self._output_idx - 1
end

---@param name                          eve.ux.widget.colorpicker.InputModeName
---@param preserve_color                boolean|nil
---@return nil
function M:set_input_mode(name, preserve_color)
  local r, g, b ---@type integer|nil, integer|nil, integer|nil
  if preserve_color then
    r, g, b = self:get_rgb()
  end
  for i, m in ipairs(INPUTS) do
    if m.name == name then
      self._input_idx = i
      break
    end
  end
  if r and g and b then
    self:set_rgb(r, g, b)
  end
end

---@param name                          eve.ux.widget.colorpicker.OutputModeName
---@return nil
function M:set_output_mode(name)
  for i, m in ipairs(OUTPUTS) do
    if m.name == name then
      self._output_idx = i
      break
    end
  end
end

---@return integer[]
function M:get()
  return { self._value[1], self._value[2], self._value[3] }
end

---@param value                         integer[]
---@return nil
function M:set(value)
  local input = self:input()
  for i = 1, 3 do
    self._value[i] = convert.clamp(value[i], 0, input.max[i])
  end
end

---@param r                             integer
---@param g                             integer
---@param b                             integer
---@return nil
function M:set_rgb(r, g, b)
  local input = self:input()
  self:set(input.from_rgb(r, g, b))
end

---@return integer, integer, integer
function M:get_rgb()
  return self:input().to_rgb(self._value)
end

---@return integer|nil
function M:get_alpha()
  return self._show_alpha and self._alpha or nil
end

---@param alpha                         integer
---@return nil
function M:set_alpha(alpha)
  self._alpha = convert.clamp(alpha, 0, 100)
end

---@return boolean
function M:is_alpha_visible()
  return self._show_alpha
end

---@return nil
function M:show_alpha()
  self._show_alpha = true
  if self._alpha == nil then
    self._alpha = 100
  end
end

---@return nil
function M:hide_alpha()
  self._show_alpha = false
end

---@return nil
function M:toggle_alpha()
  if self._show_alpha then
    self:hide_alpha()
  else
    self:show_alpha()
  end
end

---@param index                         integer
---@param new_value                     integer
---@return nil
function M:set_component(index, new_value)
  local input = self:input()
  self._value[index] = convert.clamp(new_value, 0, input.max[index])
end

---@return string
function M:hex()
  local r, g, b = self:get_rgb()
  return convert.hex_stringify(r, g, b)
end

---@param index                         integer|nil
---@param new_value                     integer|nil
---@return string
function M:hex_at(index, new_value)
  if not index or not new_value then
    return self:hex()
  end

  local org_value = self:get()
  self:set_component(index, new_value)
  local hex = self:hex()
  self:set(org_value)
  return hex
end

---@return string
function M:str()
  local r, g, b = self:get_rgb()
  return self:output().str(r, g, b, self:get_alpha())
end

---@return eve.ux.widget.colorpicker.Color
function M:copy()
  local new = M.new()
  new._value = { self._value[1], self._value[2], self._value[3] }
  new._alpha = self._alpha
  new._show_alpha = self._show_alpha
  new._input_idx = self._input_idx
  new._output_idx = self._output_idx
  return new
end

---@return nil
function M:reset()
  self._input_idx = 1
  self._output_idx = 1
  self._value = { 0, 0, 0 }
  self._alpha = nil
  self._show_alpha = false
end

return M
