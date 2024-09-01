local History = require("fc.collection.history")

---@class fc.collection.AdvanceHistory : fc.types.collection.IAdvanceHistory
---@field public name                   string
---@field public equals                 fc.types.IEquals
---@field public validate               fc.types.IValidate
---@field private _history              fc.types.collection.IHistory
local M = {}
M.__index = M

---@param element                       fc.types.T
---@return boolean
---@diagnostic disable-next-line: unused-local
local function default_validate(element)
  return true
end

---@class fc.collection.history_advance.IProps
---@field public name                   string
---@field public capacity               integer
---@field public equals                 ?fc.types.IEquals
---@field public validate               ?fc.types.IValidate

---@class fc.collection.history_advance.IDeserializeProps
---@field public data                   fc.types.collection.history.ISerializedData
---@field public name                   string
---@field public capacity               integer
---@field public equals                 ?fc.types.IEquals
---@field public validate               ?fc.types.IValidate

---@param props                         fc.collection.history_advance.IProps
---@return fc.collection.AdvanceHistory
function M.new(props)
  local name = props.name ---@type string
  local capacity = props.capacity ---@type integer
  local equals = props.equals ---@type fc.types.IEquals|nil
  local validate = props.validate or default_validate ---@type fun(element: fc.types.T): boolean
  local history = History.new({
    name = name,
    capacity = capacity,
    equals = equals,
  })

  local self = setmetatable({}, M)
  self.name = history.name
  self.equals = history.equals
  self.validate = validate
  self._history = history
  return self
end

---@param props                         fc.collection.history_advance.IDeserializeProps
---@return fc.collection.AdvanceHistory
function M.deserialize(props)
  local data = props.data ---@type fc.types.collection.history.ISerializedData

  ---@type fc.types.collection.IHistory
  local history = History.deserialize({
    data = data,
    name = props.name,
    capacity = props.capacity,
    equals = props.equals,
  })
  local validate = props.validate or default_validate ---@type fun(element: fc.types.T): boolean

  local self = setmetatable({}, M)
  self.name = history.name
  self.equals = history.equals
  self.validate = validate
  self._history = history
  return self
end

---@param step                          ?integer
---@return fc.types.T|nil
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

---@return fc.types.T[]
function M:collect()
  local results = {} ---@type fc.types.T[]
  for element in self:iterator() do
    if self.validate(element) then
      table.insert(results, element)
    end
  end
  return results
end

---@return fc.types.collection.history.ISerializedData
function M:dump()
  return self._history:dump()
end

---@param params                        fc.types.collection.history.IForkParams
---@return fc.collection.AdvanceHistory
function M:fork(params)
  local history = self._history:fork(params) ---@type fc.types.collection.IHistory
  local instance = setmetatable({}, M)
  instance.name = history.name
  instance.equals = history.equals
  instance.validate = self.validate
  instance._history = history
  return instance
end

---@param step                          ?number
---@return fc.types.T|nil
---@return boolean
function M:forward(step)
  local history = self._history ---@type fc.types.collection.IHistory
  local _, should_be_top = history:forward(step) ---@type fc.types.T|nil, boolean
  local element = self:present()
  return element, should_be_top
end

---@param index                         integer
---@return fc.types.T|nil
---@return integer
function M:go(index)
  self._history:go(index)
  return self:present()
end

---@return fun(): fc.types.T|nil, integer|nil
function M:iterator()
  local iterator = self._history:iterator() ---@type fun(): fc.types.T|nil, integer|nil

  ---@return fc.types.T|nil
  ---@return integer|nil
  return function()
    local element, index = iterator()
    if self.validate(element) then
      return element, index
    end
  end
end

---@return fun(): fc.types.T|nil, integer|nil
function M:iterator_reverse()
  local iterator = self._history:iterator_reverse() ---@type fun(): fc.types.T|nil, integer|nil

  ---@return fc.types.T|nil
  ---@return integer|nil
  return function()
    local element, index = iterator()
    if self.validate(element) then
      return element, index
    end
  end
end

---@param data                          fc.types.collection.history.ISerializedData
---@return nil
function M:load(data)
  self._history:load(data)
end

---@return fc.types.T|nil
---@return integer
function M:present()
  local history = self._history ---@type fc.types.collection.IHistory
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

---@param element                       fc.types.T
---@return nil
function M:push(element)
  if self.validate(element) then
    self._history:push(element)
  end
end

---@return nil
function M:rearrange()
  local validate = self.validate ---@type fc.types.IValidate
  self._history:rearrange(validate)
end

---@return integer
function M:size()
  return self._history:size()
end

return M
