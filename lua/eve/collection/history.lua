local CircularStack = require("eve.collection.circular_stack")
local reporter = require("eve.std.reporter")
local shallow_equals = require("eve.std.equals").shallow_equals

---@class eve.collection.History : t.eve.collection.IHistory
---@field public name                   string
---@field public equals                 t.eve.IEquals
---@field protected _present            integer
---@field protected _stack              t.eve.collection.ICircularStack
local M = {}
M.__index = M

---@class eve.collection.history.IDeserializeProps
---@field public data                   t.eve.collection.history.ISerializedData
---@field public name                   string
---@field public capacity               integer
---@field public equals                 ?t.eve.IEquals

---@class eve.collection.history.IProps
---@field public name                   string
---@field public capacity               integer
---@field public equals                 ?t.eve.IEquals

---@param props                         eve.collection.history.IProps
---@return eve.collection.History
function M.new(props)
  local name = props.name ---@type string
  local capacity = props.capacity ---@type integer
  local equals = props.equals or shallow_equals ---@type t.eve.IEquals

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
  local data = props.data ---@type t.eve.collection.history.ISerializedData

  local self = setmetatable({}, M)
  self.name = props.name
  self.equals = props.equals or shallow_equals ---@type t.eve.IEquals
  self._stack = CircularStack.from_array(data.stack, props.capacity)
  self:go(data.present or math.huge)
  return self
end

---@param step                          ?integer
---@return t.eve.T|nil
---@return boolean
function M:backward(step)
  local index = self._present - math.max(1, step or 1) ---@type integer
  local element, present = self:go(index) ---@type t.eve.T|nil, integer
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

---@return t.eve.T[]
function M:collect()
  return self._stack:collect()
end

---@return t.eve.collection.history.ISerializedData
function M:dump()
  ---@type t.eve.collection.history.ISerializedData
  return {
    present = self._present,
    stack = self._stack:collect(),
  }
end

---@param params                        t.eve.collection.history.IForkParams
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
---@return t.eve.T|nil
---@return boolean
function M:forward(step)
  local index = self._present + math.max(1, step or 1) ---@type integer
  local element, present = self:go(index) ---@type t.eve.T|nil, integer
  return element, present == self._stack:size()
end

---@param index                         integer
---@return t.eve.T|nil
---@return integer
function M:go(index)
  local stack = self._stack ---@type t.eve.collection.ICircularStack
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

---@return fun(): t.eve.T, integer
function M:iterator()
  local stack = self._stack ---@type t.eve.collection.ICircularStack
  return stack:iterator()
end

---@return fun(): t.eve.T, integer
function M:iterator_reverse()
  local stack = self._stack ---@type t.eve.collection.ICircularStack
  return stack:iterator_reverse()
end

---@param data                          t.eve.collection.history.ISerializedData
---@return nil
function M:load(data)
  local stack = data.stack ---@type t.eve.T[]
  local present = data.present ---@type integer
  self._stack:reset(stack)
  self:go(present or math.huge)
end

---@return t.eve.T|nil
---@return integer
function M:present()
  return self._stack:at(self._present), self._present
end

---@return nil
function M:print()
  local present = self._present ---@type integer
  local stack = self._stack:collect() ---@type t.eve.T
  reporter.info({
    from = "eve.collection.history",
    subject = "print",
    details = { present = present, stack = stack },
  })
end

---@param element                       t.eve.T
---@return nil
function M:push(element)
  local present = self._present ---@type integer
  local stack = self._stack ---@type t.eve.collection.ICircularStack
  local el_present = stack:at(present) ---@type t.eve.T
  if self.equals(el_present, element) then
    return
  end

  if present < stack:size() then
    local el_next = stack:at(present + 1) ---@type t.eve.T
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

---@param filter                        t.eve.IFilter
---@return nil
function M:rearrange(filter)
  local stack = self._stack ---@type t.eve.collection.ICircularStack
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

---@return t.eve.T|nil
---@return integer
function M:top()
  local stack = self._stack ---@type t.eve.collection.ICircularStack
  return stack:top(), stack:size()
end

---@param element                       t.eve.T
---@return nil
function M:update_top(element)
  local stack = self._stack ---@type t.eve.collection.ICircularStack
  local present = stack:size()
  self._present = present
  stack:update(present, element)
end

return M
