local History = require("fml.collection.history")

---@class fml.collection.AdvanceHistory : fml.types.collection.IAdvanceHistory
---@field public name                   string
---@field public equals                 fml.types.IEquals
---@field public validate               fml.types.IValidate
---@field private _history              fml.types.collection.IHistory
local M = {}
M.__index = M

---@param element                       fml.types.T
---@return boolean
---@diagnostic disable-next-line: unused-local
local function default_validate(element)
  return true
end

---@class fml.collection.history_advance.IProps
---@field public name                   string
---@field public capacity               integer
---@field public equals                 ?fml.types.IEquals
---@field public validate               ?fml.types.IValidate

---@class fml.collection.history_advance.IDeserializeProps
---@field public data                   fml.types.collection.history.ISerializedData
---@field public name                   string
---@field public capacity               integer
---@field public equals                 ?fml.types.IEquals
---@field public validate               ?fml.types.IValidate

---@param props                         fml.collection.history_advance.IProps
---@return fml.collection.AdvanceHistory
function M.new(props)
  local name = props.name ---@type string
  local capacity = props.capacity ---@type integer
  local equals = props.equals ---@type fml.types.IEquals|nil
  local validate = props.validate or default_validate ---@type fun(element: fml.types.T): boolean
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

---@param props                         fml.collection.history_advance.IDeserializeProps
---@return fml.collection.AdvanceHistory
function M.deserialize(props)
  local data = props.data ---@type fml.types.collection.history.ISerializedData

  ---@type fml.types.collection.IHistory
  local history = History.deserialize({
    data = data,
    name = props.name,
    capacity = props.capacity,
    equals = props.equals,
  })
  local validate = props.validate or default_validate ---@type fun(element: fml.types.T): boolean

  local self = setmetatable({}, M)
  self.name = history.name
  self.equals = history.equals
  self.validate = validate
  self._history = history
  return self
end

---@param step                          ?integer
---@return fml.types.T|nil
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

---@return fml.types.T[]
function M:collect()
  local results = {} ---@type fml.types.T[]
  for element in self:iterator() do
    if self.validate(element) then
      table.insert(results, element)
    end
  end
  return results
end

---@return fml.types.collection.history.ISerializedData
function M:dump()
  return self._history:dump()
end

---@param params                        fml.types.collection.history.IForkParams
---@return fml.collection.AdvanceHistory
function M:fork(params)
  local history = self._history:fork(params) ---@type fml.types.collection.IHistory
  local instance = setmetatable({}, M)
  instance.name = history.name
  instance.equals = history.equals
  instance.validate = self.validate
  instance._history = history
  return instance
end

---@param step                          ?number
---@return fml.types.T|nil
---@return boolean
function M:forward(step)
  local history = self._history ---@type fml.types.collection.IHistory
  local _, should_be_top = history:forward(step) ---@type fml.types.T|nil, boolean
  local element = self:present()
  return element, should_be_top
end

---@param index                         integer
---@return fml.types.T|nil
---@return integer
function M:go(index)
  self._history:go(index)
  return self:present()
end

---@return fun(): fml.types.T|nil, integer|nil
function M:iterator()
  local iterator = self._history:iterator() ---@type fun(): fml.types.T|nil, integer|nil

  ---@return fml.types.T|nil
  ---@return integer|nil
  return function()
    local element, index = iterator()
    if self.validate(element) then
      return element, index
    end
  end
end

---@return fun(): fml.types.T|nil, integer|nil
function M:iterator_reverse()
  local iterator = self._history:iterator_reverse() ---@type fun(): fml.types.T|nil, integer|nil

  ---@return fml.types.T|nil
  ---@return integer|nil
  return function()
    local element, index = iterator()
    if self.validate(element) then
      return element, index
    end
  end
end

---@param data                          fml.types.collection.history.ISerializedData
---@return nil
function M:load(data)
  self._history:load(data)
end

---@return fml.types.T|nil
---@return integer
function M:present()
  local history = self._history ---@type fml.types.collection.IHistory
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

---@param element                       fml.types.T
---@return nil
function M:push(element)
  if self.validate(element) then
    self._history:push(element)
  end
end

---@return nil
function M:rearrange()
  local validate = self.validate ---@type fml.types.IValidate
  self._history:rearrange(validate)
end

---@return integer
function M:size()
  return self._history:size()
end

return M
