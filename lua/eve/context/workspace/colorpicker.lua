local MAX_HISTORY = 10

---@class eve.context.colorpicker.IColorItem
---@field public hex                    string
---@field public alpha                  number|nil

---@class eve.context.colorpicker.data
---@field public history                eve.context.colorpicker.IColorItem[]
---@field public input_mode             ux.widget.colorpicker.InputModeName|nil
---@field public output_mode            ux.widget.colorpicker.OutputModeName|nil
---@field public last_color             eve.context.colorpicker.IColorItem|nil

---@class eve.context.colorpicker.state
---@field public history                ark.c.Observable
---@field public input_mode             ark.c.Observable
---@field public output_mode            ark.c.Observable
---@field public last_color             ark.c.Observable

---@class eve.context.colorpicker : eve.context.colorpicker.state
---@field public defaults               fun(): eve.context.colorpicker.data
---@field public dump                   fun(): eve.context.colorpicker.data
---@field public load                   fun(data: unknown): nil
---@field public normalize              fun(data: unknown): eve.context.colorpicker.data
---@field public push                   fun(hex: string, alpha: number|nil): nil
---@field public get                    fun(index: integer): eve.context.colorpicker.IColorItem|nil
---@field public size                   fun(): integer
---@field public set_input_mode         fun(mode: ux.widget.colorpicker.InputModeName): nil
---@field public get_input_mode         fun(): ux.widget.colorpicker.InputModeName|nil
---@field public set_output_mode        fun(mode: ux.widget.colorpicker.OutputModeName): nil
---@field public get_output_mode        fun(): ux.widget.colorpicker.OutputModeName|nil
---@field public set_last_color         fun(hex: string, alpha: number|nil): nil
---@field public get_last_color         fun(): eve.context.colorpicker.IColorItem|nil
local M = {}

---@return eve.context.colorpicker.data
function M.defaults()
  ---@type eve.context.colorpicker.data
  return {
    history = {},
    input_mode = nil,
    output_mode = nil,
    last_color = nil,
  }
end

---@param data                          any
---@return eve.context.colorpicker.data
function M.normalize(data)
  local resolved = M.defaults() ---@type eve.context.colorpicker.data
  if type(data) == "table" then
    if type(data.history) == "table" then
      for _, item in ipairs(data.history) do
        if type(item) == "table" and type(item.hex) == "string" then
          table.insert(resolved.history, {
            hex = item.hex,
            alpha = type(item.alpha) == "number" and item.alpha or nil,
          })
        end
      end
    end
    if type(data.input_mode) == "string" then
      resolved.input_mode = data.input_mode
    end
    if type(data.output_mode) == "string" then
      resolved.output_mode = data.output_mode
    end
    if type(data.last_color) == "table" and type(data.last_color.hex) == "string" then
      resolved.last_color = {
        hex = data.last_color.hex,
        alpha = type(data.last_color.alpha) == "number" and data.last_color.alpha or nil,
      }
    end
  end
  return resolved
end

---@return eve.context.colorpicker.data
function M.dump()
  ---@type eve.context.colorpicker.data
  return {
    history = M.history:snapshot(),
    input_mode = M.input_mode:snapshot(),
    output_mode = M.output_mode:snapshot(),
    last_color = M.last_color:snapshot(),
  }
end

---@param raw_data                      any
---@return nil
function M.load(raw_data)
  local data = M.normalize(raw_data) ---@type eve.context.colorpicker.data
  M.history:next(data.history)
  M.input_mode:next(data.input_mode)
  M.output_mode:next(data.output_mode)
  M.last_color:next(data.last_color)
end

---@param hex                           string
---@param alpha                         number|nil
---@return nil
function M.push(hex, alpha)
  local history = M.history:snapshot() ---@type eve.context.colorpicker.IColorItem[]
  local new_history = {} ---@type eve.context.colorpicker.IColorItem[]

  ---@type eve.context.colorpicker.IColorItem
  local new_item = { hex = hex, alpha = alpha }
  table.insert(new_history, new_item)

  for _, item in ipairs(history) do
    if item.hex ~= hex then
      table.insert(new_history, item)
      if #new_history >= MAX_HISTORY then
        break
      end
    end
  end

  M.history:next(new_history)
end

---@param index                         integer
---@return eve.context.colorpicker.IColorItem|nil
function M.get(index)
  local history = M.history:snapshot() ---@type eve.context.colorpicker.IColorItem[]
  return history[index]
end

---@return integer
function M.size()
  local history = M.history:snapshot() ---@type eve.context.colorpicker.IColorItem[]
  return #history
end

---@param mode                          ux.widget.colorpicker.InputModeName
---@return nil
function M.set_input_mode(mode)
  M.input_mode:next(mode)
end

---@return ux.widget.colorpicker.InputModeName|nil
function M.get_input_mode()
  return M.input_mode:snapshot()
end

---@param mode                          ux.widget.colorpicker.OutputModeName
---@return nil
function M.set_output_mode(mode)
  M.output_mode:next(mode)
end

---@return ux.widget.colorpicker.OutputModeName|nil
function M.get_output_mode()
  return M.output_mode:snapshot()
end

---@param hex                           string
---@param alpha                         number|nil
---@return nil
function M.set_last_color(hex, alpha)
  M.last_color:next({ hex = hex, alpha = alpha })
end

---@return eve.context.colorpicker.IColorItem|nil
function M.get_last_color()
  return M.last_color:snapshot()
end

----------------------------------------------------------------------------------------------------

local _defaults = M.defaults() ---@type eve.context.colorpicker.data

---@type ark.c.Observable
M.history = ark.c.Observable.from_value(_defaults.history)

---@type ark.c.Observable
M.input_mode = ark.c.Observable.from_value(_defaults.input_mode)

---@type ark.c.Observable
M.output_mode = ark.c.Observable.from_value(_defaults.output_mode)

---@type ark.c.Observable
M.last_color = ark.c.Observable.from_value(_defaults.last_color)

return M
