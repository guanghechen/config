local CircularQueue = require("eve.collection.circular_queue")
local reporter = require("eve.std.reporter")

---@param x                             eve.types.T
---@param y                             eve.types.T
---@return boolean
local function default_equals(x, y)
  return x == y
end

---@class eve.collection.History : eve.types.collection.IHistory
---@field public name                   string
---@field public equals                 eve.types.IEquals
---@field protected _present            integer
---@field protected _stack              eve.types.collection.ICircularQueue
local M = {}
M.__index = M

---@class eve.collection.history.IDeserializeProps
---@field public data                   eve.types.collection.history.ISerializedData
---@field public name                   string
---@field public capacity               integer
---@field public equals                 ?eve.types.IEquals

---@class eve.collection.history.IProps
---@field public name                   string
---@field public capacity               integer
---@field public equals                 ?eve.types.IEquals

---@param props                         eve.collection.history.IProps
---@return eve.collection.History
function M.new(props)
  local name = props.name ---@type string
  local capacity = props.capacity ---@type integer
  local equals = props.equals or default_equals ---@type eve.types.IEquals

  local self = setmetatable({}, M)
  self.name = name
  self.equals = equals
  self._present = 0
  self._stack = CircularQueue.new({ capacity = capacity })
  return self
end

---@param props                         eve.collection.history.IDeserializeProps
---@return eve.collection.History
function M.deserialize(props)
  local data = props.data ---@type eve.types.collection.history.ISerializedData

  local self = setmetatable({}, M)
  self.name = props.name
  self.equals = props.equals or default_equals
  self._stack = CircularQueue.from_array(data.stack, props.capacity)
  self:go(data.present or math.huge)
  return self
end

---@param step                          ?integer
---@return eve.types.T|nil
---@return boolean
function M:backward(step)
  local index = self._present - math.max(1, step or 1) ---@type integer
  local element, present = self:go(index) ---@type eve.types.T|nil, integer
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

---@return eve.types.T[]
function M:collect()
  return self._stack:collect()
end

---@return eve.types.collection.history.ISerializedData
function M:dump()
  ---@type eve.types.collection.history.ISerializedData
  return {
    present = self._present,
    stack = self._stack:collect(),
  }
end

---@param params                        eve.types.collection.history.IForkParams
---@return eve.collection.History
function M:fork(params)
  local instance = setmetatable({}, M)
  instance.name = params.name
  instance.equals = self.equals
  instance._present = self._present
  instance._stack = CircularQueue.from(self._stack)
  return instance
end

---@param step                          ?integer
---@return eve.types.T|nil
---@return boolean
function M:forward(step)
  local index = self._present + math.max(1, step or 1) ---@type integer
  local element, present = self:go(index) ---@type eve.types.T|nil, integer
  return element, present == self._stack:size()
end

---@param index                         integer
---@return eve.types.T|nil
---@return integer
function M:go(index)
  local stack = self._stack ---@type eve.types.collection.ICircularQueue
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

---@return fun(): eve.types.T, integer
function M:iterator()
  local stack = self._stack ---@type eve.types.collection.ICircularQueue
  return stack:iterator()
end

---@return fun(): eve.types.T, integer
function M:iterator_reverse()
  local stack = self._stack ---@type eve.types.collection.ICircularQueue
  return stack:iterator_reverse()
end

---@param data                          eve.types.collection.history.ISerializedData
---@return nil
function M:load(data)
  local stack = data.stack ---@type eve.types.T[]
  local present = data.present ---@type integer
  self._stack:reset(stack)
  self:go(present or math.huge)
end

---@return eve.types.T|nil
---@return integer|nil
function M:present()
  return self._stack:at(self._present), self._present
end

---@return nil
function M:print()
  local present = self._present ---@type integer
  local stack = self._stack:collect() ---@type eve.types.T
  reporter.info({
    from = "eve.collection.history",
    subject = "print",
    details = { present = present, stack = stack },
  })
end

---@param element                       eve.types.T
---@return nil
function M:push(element)
  local present = self._present ---@type integer
  local stack = self._stack ---@type eve.types.collection.ICircularQueue
  local el_present = stack:at(present) ---@type eve.types.T
  if self.equals(el_present, element) then
    return
  end

  if present < stack:size() then
    local el_next = stack:at(present + 1) ---@type eve.types.T
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

---@param filter                        eve.types.IFilter
---@return nil
function M:rearrange(filter)
  local stack = self._stack ---@type eve.types.collection.ICircularQueue
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

---@return eve.types.T|nil
---@return integer
function M:top()
  local stack = self._stack ---@type eve.types.collection.ICircularQueue
  return stack:back(), stack:size()
end

---@param element                       eve.types.T
---@return nil
function M:update_top(element)
  local stack = self._stack ---@type eve.types.collection.ICircularQueue
  local present = stack:size()
  self._present = present
  stack:update(present, element)
end

return M
