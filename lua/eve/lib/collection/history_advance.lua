local History = require("eve.lib.collection.history")

---@class eve.lib.collection.IAdvanceHistory
---@field public name                   string
---@field public equals                 eve.t.IEquals
---@field public validate               eve.t.IValidate
---@field public backward               fun(self: eve.lib.collection.IAdvanceHistory, step?: integer): eve.t.T|nil, boolean
---@field public capacity               fun(self: eve.lib.collection.IAdvanceHistory): integer
---@field public clear                  fun(self: eve.lib.collection.IAdvanceHistory): nil
---@field public dump                   fun(self: eve.lib.collection.IAdvanceHistory): eve.lib.collection.history.ISerializedData
---@field public fork                   fun(self: eve.lib.collection.IAdvanceHistory, params?: eve.lib.collection.history.IForkParams): eve.lib.collection.IAdvanceHistory
---@field public forward                fun(self: eve.lib.collection.IAdvanceHistory, step?: integer): eve.t.T|nil, boolean
---@field public go                     fun(self: eve.lib.collection.IAdvanceHistory, index: integer): eve.t.T|nil
---@field public iterator               fun(self: eve.lib.collection.IAdvanceHistory): fun(): eve.t.T|nil, integer|nil
---@field public iterator_reverse       fun(self: eve.lib.collection.IAdvanceHistory): fun(): eve.t.T|nil, integer|nil
---@field public load                   fun(self: eve.lib.collection.IAdvanceHistory, data: eve.lib.collection.history.ISerializedData): nil
---@field public present                fun(self: eve.lib.collection.IAdvanceHistory): eve.t.T|nil, integer
---@field public print                  fun(self: eve.lib.collection.IAdvanceHistory): nil
---@field public push                   fun(self: eve.lib.collection.IAdvanceHistory, element: eve.t.T|nil): nil
---@field public rearrange              fun(self: eve.lib.collection.IAdvanceHistory): nil
---@field public size                   fun(self: eve.lib.collection.IAdvanceHistory): integer

---@class eve.lib.collection.history_advance.IProps
---@field public name                   string
---@field public capacity               integer
---@field public equals                 ?eve.t.IEquals
---@field public validate               ?eve.t.IValidate

---@class eve.lib.collection.history_advance.IDeserializeProps
---@field public data                   eve.lib.collection.history.ISerializedData
---@field public name                   string
---@field public capacity               integer
---@field public equals                 ?eve.t.IEquals
---@field public validate               ?eve.t.IValidate

---@param element                       eve.t.T
---@return boolean
---@diagnostic disable-next-line: unused-local
local function default_validate(element)
  return true
end

---@class eve.lib.collection.AdvanceHistory : eve.lib.collection.IAdvanceHistory
---@field public name                   string
---@field public equals                 eve.t.IEquals
---@field public validate               eve.t.IValidate
---@field private _history              eve.lib.collection.IHistory
local M = {}

---@param props                         eve.lib.collection.history_advance.IProps
---@return eve.lib.collection.AdvanceHistory
function M.new(props)
  local name = props.name ---@type string
  local capacity = props.capacity ---@type integer
  local equals = props.equals ---@type eve.t.IEquals|nil
  local validate = props.validate or default_validate ---@type fun(element: eve.t.T): boolean
  local history = History.new({
    name = name,
    capacity = capacity,
    equals = equals,
  })

  local self = setmetatable({}, { __index = M })
  self.name = history.name
  self.equals = history.equals
  self.validate = validate
  self._history = history
  return self
end

---@param props                         eve.lib.collection.history_advance.IDeserializeProps
---@return eve.lib.collection.AdvanceHistory
function M.deserialize(props)
  local data = props.data ---@type eve.lib.collection.history.ISerializedData

  ---@type eve.lib.collection.IHistory
  local history = History.deserialize({
    data = data,
    name = props.name,
    capacity = props.capacity,
    equals = props.equals,
  })
  local validate = props.validate or default_validate ---@type fun(element: eve.t.T): boolean

  local self = setmetatable({}, M)
  self.name = history.name
  self.equals = history.equals
  self.validate = validate
  self._history = history
  return self
end

---@param step                          ?integer
---@return eve.t.T|nil
---@return boolean
function M:backward(step)
  self._history:backward(step)
  local element, index = self:present()
  return element, index <= 1
end

---@return integer
function M:capacity()
  return self._history:capacity()
end

---@return nil
function M:clear()
  self._history:clear()
end

---@return eve.t.T[]
function M:collect()
  local results = {} ---@type eve.t.T[]
  for element in self:iterator() do
    if self.validate(element) then
      table.insert(results, element)
    end
  end
  return results
end

---@return eve.lib.collection.history.ISerializedData
function M:dump()
  return self._history:dump()
end

---@param params                        eve.lib.collection.history.IForkParams
---@return eve.lib.collection.AdvanceHistory
function M:fork(params)
  local history = self._history:fork(params) ---@type eve.lib.collection.IHistory
  local instance = setmetatable({}, M)
  instance.name = history.name
  instance.equals = history.equals
  instance.validate = self.validate
  instance._history = history
  return instance
end

---@param step                          ?number
---@return eve.t.T|nil
---@return boolean
function M:forward(step)
  local history = self._history ---@type eve.lib.collection.IHistory
  local _, should_be_top = history:forward(step) ---@type eve.t.T|nil, boolean
  local element = self:present()
  return element, should_be_top
end

---@param index                         integer
---@return eve.t.T|nil
---@return integer
function M:go(index)
  self._history:go(index)
  return self:present()
end

---@return fun(): eve.t.T|nil, integer|nil
function M:iterator()
  local iterator = self._history:iterator() ---@type fun(): eve.t.T|nil, integer|nil

  ---@return eve.t.T|nil
  ---@return integer|nil
  return function()
    local element, index = iterator()
    if self.validate(element) then
      return element, index
    end
  end
end

---@return fun(): eve.t.T|nil, integer|nil
function M:iterator_reverse()
  local iterator = self._history:iterator_reverse() ---@type fun(): eve.t.T|nil, integer|nil

  ---@return eve.t.T|nil
  ---@return integer|nil
  return function()
    local element, index = iterator()
    if self.validate(element) then
      return element, index
    end
  end
end

---@param data                          eve.lib.collection.history.ISerializedData
---@return nil
function M:load(data)
  self._history:load(data)
end

---@return eve.t.T|nil
---@return integer
function M:present()
  local history = self._history ---@type eve.lib.collection.IHistory
  while true do
    local element, index = history:present()
    if element ~= nil and self.validate(element) then
      return element, index
    end

    if index <= 1 then
      return nil, 0
    end

    history:backward()
  end
end

---@return nil
function M:print()
  self._history:print()
end

---@param element                       eve.t.T
---@return nil
function M:push(element)
  if self.validate(element) then
    self._history:push(element)
  end
end

---@return nil
function M:rearrange()
  local validate = self.validate ---@type eve.t.IValidate
  self._history:rearrange(validate)
end

---@return integer
function M:size()
  return self._history:size()
end

return M
