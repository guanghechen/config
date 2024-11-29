local reporter = require("eve.builtin.reporter")
local CircularStack = require("eve.collection.circular_stack")
local util = require("eve.std.util")

---@class eve.collection.History : eve.t.collection.IHistory
---@field public name                   string
---@field public equals                 eve.t.IEquals
---@field protected _present            integer
---@field protected _stack              eve.t.collection.ICircularStack
local M = {}
M.__index = M

---@class eve.collection.history.IDeserializeProps
---@field public data                   eve.t.collection.history.ISerializedData
---@field public name                   string
---@field public capacity               integer
---@field public equals                 ?eve.t.IEquals

---@class eve.collection.history.IProps
---@field public name                   string
---@field public capacity               integer
---@field public equals                 ?eve.t.IEquals

---@param props                         eve.collection.history.IProps
---@return eve.collection.History
function M.new(props)
  local name = props.name ---@type string
  local capacity = props.capacity ---@type integer
  local equals = props.equals or util.shallow_equals ---@type eve.t.IEquals

  local self = setmetatable({}, M)
  self.name = name
  self.equals = equals
  self._present = 0
  self._stack = CircularStack.new({ capacity = capacity })
  return self
end

---@param props                         eve.collection.history.IDeserializeProps
---@return eve.collection.History
function M.deserialize(props)
  local data = props.data ---@type eve.t.collection.history.ISerializedData

  local self = setmetatable({}, M)
  self.name = props.name
  self.equals = props.equals or util.shallow_equals ---@type eve.t.IEquals
  self._stack = CircularStack.from_array(data.stack, props.capacity)
  self:go(data.present or math.huge)
  return self
end

---@param step                          ?integer
---@return eve.t.T|nil
---@return boolean
function M:backward(step)
  local index = self._present - math.max(1, step or 1) ---@type integer
  local element, present = self:go(index) ---@type eve.t.T|nil, integer
  return element, present <= 1
end

---@return eve.t.T|nil
function M:bottom()
  return self._stack:at(1)
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

---@return eve.t.T[]
function M:collect()
  return self._stack:collect()
end

---@return eve.t.collection.history.ISerializedData
function M:dump()
  ---@type eve.t.collection.history.ISerializedData
  return {
    present = self._present,
    stack = self._stack:collect(),
  }
end

---@param params                        eve.t.collection.history.IForkParams
---@return eve.collection.History
function M:fork(params)
  local instance = setmetatable({}, M)
  instance.name = params.name
  instance.equals = self.equals
  instance._present = self._present
  instance._stack = CircularStack.from(self._stack)
  return instance
end

---@param step                          ?integer
---@return eve.t.T|nil
---@return boolean
function M:forward(step)
  local index = self._present + math.max(1, step or 1) ---@type integer
  local element, present = self:go(index) ---@type eve.t.T|nil, integer
  return element, present == self._stack:size()
end

---@param index                         integer
---@return eve.t.T|nil
---@return integer
function M:go(index)
  local stack = self._stack ---@type eve.t.collection.ICircularStack
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

---@return fun(): eve.t.T, integer
function M:iterator()
  local stack = self._stack ---@type eve.t.collection.ICircularStack
  return stack:iterator()
end

---@return fun(): eve.t.T, integer
function M:iterator_reverse()
  local stack = self._stack ---@type eve.t.collection.ICircularStack
  return stack:iterator_reverse()
end

---@param data                          eve.t.collection.history.ISerializedData
---@return nil
function M:load(data)
  local stack = data.stack ---@type eve.t.T[]
  local present = data.present ---@type integer
  self._stack:reset(stack)
  self:go(present or math.huge)
end

---@return eve.t.T|nil
---@return integer
function M:present()
  return self._stack:at(self._present), self._present
end

---@return nil
function M:print()
  local present = self._present ---@type integer
  local stack = self._stack:collect() ---@type eve.t.T
  reporter.info({
    from = "eve.collection.history",
    subject = "print",
    details = { present = present, stack = stack },
  })
end

---@param element                       eve.t.T
---@return nil
function M:push(element)
  local present = self._present ---@type integer
  local stack = self._stack ---@type eve.t.collection.ICircularStack
  local el_present = stack:at(present) ---@type eve.t.T|nil
  if el_present ~= nil and self.equals(el_present, element) then
    return
  end

  if present < stack:size() then
    local el_next = stack:at(present + 1) ---@type eve.t.T
    if self.equals(el_next, element) then
      self._present = present + 1
      return
    end
  end

  while present < stack:size() do
    stack:pop()
  end
  stack:push(element)
  self._present = stack:size()
end

---@param filter                        eve.t.IFilter
---@return nil
function M:rearrange(filter)
  local stack = self._stack ---@type eve.t.collection.ICircularStack
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

---@return eve.t.T|nil
---@return integer
function M:top()
  local stack = self._stack ---@type eve.t.collection.ICircularStack
  return stack:top(), stack:size()
end

---@param element                       eve.t.T
---@return nil
function M:update_top(element)
  local stack = self._stack ---@type eve.t.collection.ICircularStack
  local present = stack:size()
  self._present = present
  stack:update(present, element)
end

return M
