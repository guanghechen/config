local MAX_HISTORY = 10

---@class eve.context.colorpicker.IHistoryItem
---@field public hex                    string
---@field public alpha                  number|nil

---@class eve.context.colorpicker.data
---@field public history                eve.context.colorpicker.IHistoryItem[]

---@class eve.context.colorpicker.state
---@field public history                std.collection.IObservable

---@class eve.context.colorpicker : eve.context.colorpicker.state
---@field public defaults               fun(): eve.context.colorpicker.data
---@field public dump                   fun(): eve.context.colorpicker.data
---@field public load                   fun(data: unknown): nil
---@field public normalize              fun(data: unknown): eve.context.colorpicker.data
---@field public push                   fun(hex: string, alpha: number|nil): nil
---@field public get                    fun(index: integer): eve.context.colorpicker.IHistoryItem|nil
---@field public size                   fun(): integer
local M = {}

---@return eve.context.colorpicker.data
function M.defaults()
  ---@type eve.context.colorpicker.data
  return {
    history = {},
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
  end
  return resolved
end

---@return eve.context.colorpicker.data
function M.dump()
  ---@type eve.context.colorpicker.data
  return {
    history = M.history:snapshot(),
  }
end

---@param raw_data                      any
---@return nil
function M.load(raw_data)
  local data = M.normalize(raw_data) ---@type eve.context.colorpicker.data
  M.history:next(data.history)
end

---@param hex                           string
---@param alpha                         number|nil
---@return nil
function M.push(hex, alpha)
  local history = M.history:snapshot() ---@type eve.context.colorpicker.IHistoryItem[]
  local new_history = {} ---@type eve.context.colorpicker.IHistoryItem[]

  ---@type eve.context.colorpicker.IHistoryItem
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
---@return eve.context.colorpicker.IHistoryItem|nil
function M.get(index)
  local history = M.history:snapshot() ---@type eve.context.colorpicker.IHistoryItem[]
  return history[index]
end

---@return integer
function M.size()
  local history = M.history:snapshot() ---@type eve.context.colorpicker.IHistoryItem[]
  return #history
end

----------------------------------------------------------------------------------------------------

local _defaults = M.defaults() ---@type eve.context.colorpicker.data

---@type std.collection.IObservable
M.history = std.Observable.from_value(_defaults.history)

return M
