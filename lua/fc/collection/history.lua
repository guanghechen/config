local CircularQueue = require("fc.collection.circular_queue")
local reporter = require("fc.std.reporter")

---@param x                             fc.types.T
---@param y                             fc.types.T
---@return boolean
local function default_equals(x, y)
  return x == y
end

---@class fc.collection.History : fc.types.collection.IHistory
---@field public name                   string
---@field public equals                 fc.types.IEquals
---@field protected _present            integer
---@field protected _stack              fc.types.collection.ICircularQueue
local M = {}
M.__index = M

---@class fc.collection.history.IDeserializeProps
---@field public data                   fc.types.collection.history.ISerializedData
---@field public name                   string
---@field public capacity               integer
---@field public equals                 ?fc.types.IEquals

---@class fc.collection.history.IProps
---@field public name                   string
---@field public capacity               integer
---@field public equals                 ?fc.types.IEquals

---@param props                         fc.collection.history.IProps
---@return fc.collection.History
function M.new(props)
  local name = props.name ---@type string
  local capacity = props.capacity ---@type integer
  local equals = props.equals or default_equals ---@type fc.types.IEquals

  local self = setmetatable({}, M)
  self.name = name
  self.equals = equals
  self._present = 0
  self._stack = CircularQueue.new({ capacity = capacity })
  return self
end

---@param props                         fc.collection.history.IDeserializeProps
---@return fc.collection.History
function M.deserialize(props)
  local data = props.data ---@type fc.types.collection.history.ISerializedData

  local self = setmetatable({}, M)
  self.name = props.name
  self.equals = props.equals or default_equals
  self._stack = CircularQueue.from_array(data.stack, props.capacity)
  self:go(data.present or math.huge)
  return self
end

---@param step                          ?integer
---@return fc.types.T|nil
---@return boolean
function M:backward(step)
  local index = self._present - math.max(1, step or 1) ---@type integer
  local element, present = self:go(index) ---@type fc.types.T|nil, integer
  return element, present <= 1
end

---@return integer
function M:capacity()
  return self._stack:capacity()
end

---@return nil
function M:clear()
  self._present = 0
  self._stack:clear()
end

---@return fc.types.T[]
function M:collect()
  return self._stack:collect()
end

---@return fc.types.collection.history.ISerializedData
function M:dump()
  ---@type fc.types.collection.history.ISerializedData
  return {
    present = self._present,
    stack = self._stack:collect(),
  }
end

---@param params                        fc.types.collection.history.IForkParams
---@return fc.collection.History
function M:fork(params)
  local instance = setmetatable({}, M)
  instance.name = params.name
  instance.equals = self.equals
  instance._present = self._present
  instance._stack = CircularQueue.from(self._stack)
  return instance
end

---@param step                          ?integer
---@return fc.types.T|nil
---@return boolean
function M:forward(step)
  local index = self._present + math.max(1, step or 1) ---@type integer
  local element, present = self:go(index) ---@type fc.types.T|nil, integer
  return element, present == self._stack:size()
end

---@param index                         integer
---@return fc.types.T|nil
---@return integer
function M:go(index)
  local stack = self._stack ---@type fc.types.collection.ICircularQueue
  local present = math.min(stack:size(), math.max(1, index)) ---@type integer
  self._present = present
  return stack:at(present), present
end

---@return boolean
function M:is_bottom()
  return self._present <= 1
end

---@return boolean
function M:is_empty()
  return self._stack:size() == 0
end

---@return boolean
function M:is_top()
  return self._present == self._stack:size()
end

---@return fun(): fc.types.T, integer
function M:iterator()
  local stack = self._stack ---@type fc.types.collection.ICircularQueue
  return stack:iterator()
end

---@return fun(): fc.types.T, integer
function M:iterator_reverse()
  local stack = self._stack ---@type fc.types.collection.ICircularQueue
  return stack:iterator_reverse()
end

---@param data                          fc.types.collection.history.ISerializedData
---@return nil
function M:load(data)
  local stack = data.stack ---@type fc.types.T[]
  local present = data.present ---@type integer
  self._stack:reset(stack)
  self:go(present or math.huge)
end

---@return fc.types.T|nil
---@return integer|nil
function M:present()
  return self._stack:at(self._present), self._present
end

---@return nil
function M:print()
  local present = self._present ---@type integer
  local stack = self._stack:collect() ---@type fc.types.T
  reporter.info({
    from = "fc.collection.history",
    subject = "print",
    details = { present = present, stack = stack },
  })
end

---@param element                       fc.types.T
---@return nil
function M:push(element)
  local present = self._present ---@type integer
  local stack = self._stack ---@type fc.types.collection.ICircularQueue
  local el_present = stack:at(present) ---@type fc.types.T
  if self.equals(el_present, element) then
    return
  end

  if present < stack:size() then
    local el_next = stack:at(present + 1) ---@type fc.types.T
    if self.equals(el_next, element) then
      self._present = present + 1
      return
    end
  end

  while present < stack:size() do
    stack:dequeue_back()
  end
  stack:enqueue(element)
  self._present = stack:size()
end

---@param filter                        fc.types.IFilter
---@return nil
function M:rearrange(filter)
  local stack = self._stack ---@type fc.types.collection.ICircularQueue
  local old_present = self._present ---@type integer
  local new_present = 0 ---@type integer
  local idx = 0 ---@type integer

  stack:rearrange(function(element, index)
    if filter(element, index) then
      idx = idx + 1
      if index < old_present then
        new_present = idx
      end
      return true
    end
    return false
  end)

  local present = math.min(stack:size(), math.max(1, new_present)) ---@type integer
  self._present = present
end

---@return integer
function M:size()
  return self._stack:size()
end

---@return fc.types.T|nil
---@return integer
function M:top()
  local stack = self._stack ---@type fc.types.collection.ICircularQueue
  return stack:back(), stack:size()
end

---@param element                       fc.types.T
---@return nil
function M:update_top(element)
  local stack = self._stack ---@type fc.types.collection.ICircularQueue
  local present = stack:size()
  self._present = present
  stack:update(present, element)
end

return M
