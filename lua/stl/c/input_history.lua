local __module_name__ = "stl.c.input_history" ---@type string

---@class stl.c.InputHistory : stl.c.History
---@field public fullname               string
---@field public equals                 ark.t.IEquals
---@field protected _present            integer
---@field protected _stack              stl.c.CircularStack
local M = {}
M.__index = M

---@param props                         stl.c.history.IProps
---@return stl.c.InputHistory
function M.new(props)
  local name = props.name ---@type string
  local fullname = string.format("%s -> %s", name, __module_name__) ---@type string
  local capacity = props.capacity ---@type integer
  local equals = props.equals or stl.fn.equals_shallow ---@type ark.t.IEquals

  local self = setmetatable({}, M)
  self.fullname = fullname
  self.equals = equals
  self._present = 0
  self._stack = stl.c.CircularStack.new({ capacity = capacity })
  return self
end

---@param props                         stl.c.history.IDeserializeProps
---@return stl.c.InputHistory
function M.deserialize(props)
  local name = props.name ---@type string
  local fullname = string.format("%s -> %s", name, __module_name__) ---@type string
  local data = props.data ---@type stl.c.history.ISerializedData

  local self = setmetatable({}, M)
  self.fullname = fullname
  self.equals = props.equals or stl.fn.equals_shallow ---@type ark.t.IEquals
  self._stack = stl.c.CircularStack.from_array(data.stack, props.capacity)
  self:go(data.present or math.huge)
  return self
end

---@param index                         integer
---@return ark.t.T|nil
function M:at(index)
  return self._stack:at(index)
end

---@param step                          ?integer
---@return ark.t.T|nil
---@return boolean
function M:backward(step)
  local index = self._present - math.max(1, step or 1) ---@type integer
  local element, present = self:go(index) ---@type ark.t.T|nil, integer
  return element, present <= 1
end

---@return ark.t.T|nil
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

---@return ark.t.T[]
function M:collect()
  return self._stack:collect()
end

---@return stl.c.history.ISerializedData
function M:dump()
  ---@type stl.c.history.ISerializedData
  return {
    present = self._present,
    stack = self._stack:collect(),
  }
end

---@param params                        stl.c.history.IForkParams
---@return stl.c.InputHistory
function M:fork(params)
  local name = params.name ---@type string
  local fullname = string.format("%s -> %s", name, __module_name__) ---@type string

  local instance = setmetatable({}, M)
  instance.fullname = fullname
  instance.equals = self.equals
  instance._present = self._present
  instance._stack = stl.c.CircularStack.from(self._stack)
  return instance
end

---@param step                          ?integer
---@return ark.t.T|nil
---@return boolean
function M:forward(step)
  local index = self._present + math.max(1, step or 1) ---@type integer
  local element, present = self:go(index) ---@type ark.t.T|nil, integer
  return element, present == self._stack:size()
end

---@param index                         integer
---@return ark.t.T|nil
---@return integer
function M:go(index)
  local stack = self._stack ---@type stl.c.CircularStack
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

---@return fun(): ark.t.T, integer
function M:iterator()
  local stack = self._stack ---@type stl.c.CircularStack
  return stack:iterator()
end

---@return fun(): ark.t.T, integer
function M:iterator_reverse()
  local stack = self._stack ---@type stl.c.CircularStack
  return stack:iterator_reverse()
end

---@param data                          stl.c.history.ISerializedData
---@return nil
function M:load(data)
  local stack = data.stack ---@type ark.t.T[]
  local present = data.present ---@type integer
  self._stack:reset(stack)
  self:go(present or math.huge)
end

---@return ark.t.T|nil
---@return integer
function M:present()
  return self._stack:at(self._present), self._present
end

---@return nil
function M:print()
  local present = self._present ---@type integer
  local stack = self._stack:collect() ---@type ark.t.T
  ark.reporter.info({
    from = self.fullname,
    subject = "print",
    details = { present = present, stack = stack },
  })
end

---@param element                       ark.t.T
---@return nil
function M:push(element)
  local present = self._stack:at(self._present) ---@type ark.t.T|nil
  if present ~= nil and self.equals(present, element) then
    return
  end

  local stack = self._stack ---@type stl.c.CircularStack
  self:rearrange(function(item)
    return not self.equals(item, element)
  end)
  stack:push(element)
  self._present = stack:size()
end

---@param filter                        ark.t.IFilter
---@return nil
function M:rearrange(filter)
  local stack = self._stack ---@type stl.c.CircularStack
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

---@return ark.t.T|nil
---@return integer
function M:top()
  local stack = self._stack ---@type stl.c.CircularStack
  return stack:top(), stack:size()
end

---@param element                       ark.t.T
---@return nil
function M:update_top(element)
  local stack = self._stack ---@type stl.c.CircularStack
  local present = stack:size()
  self._present = present
  stack:update(present, element)
end

return M
