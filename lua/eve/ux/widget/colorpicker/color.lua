local convert = require("eve.ux.widget.colorpicker.convert")
local mode = require("eve.ux.widget.colorpicker.mode")

local INPUTS = { mode.input.hex, mode.input.rgb, mode.input.hsl, mode.input.hsv }
local OUTPUTS = { mode.output.hex, mode.output.rgb, mode.output.hsl, mode.output.hsv }

---@param name                          eve.ux.widget.colorpicker.InputModeName|nil
---@return integer
local function get_input_idx(name)
  if name then
    for i, m in ipairs(INPUTS) do
      if m.name == name then
        return i
      end
    end
  end
  return 1
end

---@param name                          eve.ux.widget.colorpicker.OutputModeName|nil
---@return integer
local function get_output_idx(name)
  if name then
    for i, m in ipairs(OUTPUTS) do
      if m.name == name then
        return i
      end
    end
  end
  return 1
end

---@class eve.ux.widget.colorpicker.Color
---@field protected _value              integer[]
---@field protected _alpha              integer|nil
---@field protected _show_alpha         boolean
local M = {}
M.__index = M

---@return eve.ux.widget.colorpicker.Color
function M.new()
  local self = setmetatable({}, M)
  self._value = { 0, 0, 0 }
  self._alpha = nil
  self._show_alpha = false
  return self
end

---@return eve.ux.widget.colorpicker.IInputMode
function M:input()
  local name = eve.context.colorpicker.get_input_mode() ---@type eve.ux.widget.colorpicker.InputModeName|nil
  local idx = get_input_idx(name) ---@type integer
  return INPUTS[idx]
end

---@return eve.ux.widget.colorpicker.IOutputMode
function M:output()
  local name = eve.context.colorpicker.get_output_mode() ---@type eve.ux.widget.colorpicker.OutputModeName|nil
  local idx = get_output_idx(name) ---@type integer
  return OUTPUTS[idx]
end

---@return nil
function M:cycle_input()
  local r, g, b = self:get_rgb() ---@type integer, integer, integer
  local name = eve.context.colorpicker.get_input_mode() ---@type eve.ux.widget.colorpicker.InputModeName|nil
  local idx = get_input_idx(name) % #INPUTS + 1 ---@type integer
  eve.context.colorpicker.set_input_mode(INPUTS[idx].name)
  self:set_rgb(r, g, b)
end

---@return nil
function M:cycle_input_reverse()
  local r, g, b = self:get_rgb() ---@type integer, integer, integer
  local name = eve.context.colorpicker.get_input_mode() ---@type eve.ux.widget.colorpicker.InputModeName|nil
  local idx = (get_input_idx(name) - 2) % #INPUTS + 1 ---@type integer
  eve.context.colorpicker.set_input_mode(INPUTS[idx].name)
  self:set_rgb(r, g, b)
end

---@return nil
function M:cycle_output()
  local name = eve.context.colorpicker.get_output_mode() ---@type eve.ux.widget.colorpicker.OutputModeName|nil
  local idx = get_output_idx(name) % #OUTPUTS + 1 ---@type integer
  eve.context.colorpicker.set_output_mode(OUTPUTS[idx].name)
end

---@return nil
function M:cycle_output_reverse()
  local name = eve.context.colorpicker.get_output_mode() ---@type eve.ux.widget.colorpicker.OutputModeName|nil
  local idx = (get_output_idx(name) - 2) % #OUTPUTS + 1 ---@type integer
  eve.context.colorpicker.set_output_mode(OUTPUTS[idx].name)
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
  self:set(self:input().from_rgb(r, g, b))
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
  self._show_alpha = not self._show_alpha
  if self._show_alpha and self._alpha == nil then
    self._alpha = 100
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
  return new
end

---@return nil
function M:reset()
  self._value = { 0, 0, 0 }
  self._alpha = nil
  self._show_alpha = false
end

return M
