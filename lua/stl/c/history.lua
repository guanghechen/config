---@diagnostic disable-next-line: unused-local
local __module_name__ = "stl.c.history" ---@type string

---@class stl.c.history.IForkParams
---@field public name                   ?string

---@class stl.c.history.ISerializedData
---@field public present                integer
---@field public stack                  stl.t.T[]

---@class stl.c.history.IDeserializeProps
---@field public data                   stl.c.history.ISerializedData
---@field public name                   string
---@field public capacity               integer
---@field public equals                 ?stl.t.IEquals

---@class stl.c.history.IProps
---@field public name                   string
---@field public capacity               integer
---@field public equals                 ?stl.t.IEquals

---@class stl.c.History
---@field public name                   string
---@field public fullname               string
---@field public equals                 stl.t.IEquals
---@field protected _present            integer
---@field protected _stack              stl.c.CircularStack
local M = {}
M.__index = M

---@param props                         stl.c.history.IProps
---@return stl.c.History
function M.new(props)
  local name = props.name ---@type string
  local fullname = string.format("%s -> %s", name, __module_name__) ---@type string
  local capacity = props.capacity ---@type integer
  local equals = props.equals or stl.fn.equals_shallow ---@type stl.t.IEquals

  local self = setmetatable({}, M)
  self.fullname = fullname
  self.equals = equals
  self._present = 0
  self._stack = stl.c.CircularStack.new({ capacity = capacity })
  return self
end

---@param props                         stl.c.history.IDeserializeProps
---@return stl.c.History
function M.deserialize(props)
  local name = props.name ---@type string
  local fullname = string.format("%s -> %s", name, __module_name__) ---@type string
  local data = props.data ---@type stl.c.history.ISerializedData

  local self = setmetatable({}, M)
  self.fullname = fullname
  self.equals = props.equals or stl.fn.equals_shallow ---@type stl.t.IEquals
  self._stack = stl.c.CircularStack.from_array(data.stack, props.capacity)
  self:go(data.present or math.huge)
  return self
end

---@param index                         integer
---@return stl.t.T|nil
function M:at(index)
  return self._stack:at(index)
end

---@param step                          ?integer
---@return stl.t.T|nil
---@return boolean
function M:backward(step)
  local index = self._present - math.max(1, step or 1) ---@type integer
  local element, present = self:go(index) ---@type stl.t.T|nil, integer
  return element, present <= 1
end

---@return stl.t.T|nil
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

---@return stl.t.T[]
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
---@return stl.c.History
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
---@return stl.t.T|nil
---@return boolean
function M:forward(step)
  local index = self._present + math.max(1, step or 1) ---@type integer
  local element, present = self:go(index) ---@type stl.t.T|nil, integer
  return element, present == self._stack:size()
end

---@param index                         integer
---@return stl.t.T|nil
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

---@return fun(): stl.t.T, integer
function M:iterator()
  local stack = self._stack ---@type stl.c.CircularStack
  return stack:iterator()
end

---@return fun(): stl.t.T, integer
function M:iterator_reverse()
  local stack = self._stack ---@type stl.c.CircularStack
  return stack:iterator_reverse()
end

---@param data                          stl.c.history.ISerializedData
---@return nil
function M:load(data)
  local stack = data.stack ---@type stl.t.T[]
  local present = data.present ---@type integer
  self._stack:reset(stack)
  self:go(present or math.huge)
end

---@return stl.t.T|nil
---@return integer
function M:present()
  return self._stack:at(self._present), self._present
end

---@return nil
function M:print()
  local present = self._present ---@type integer
  local stack = self._stack:collect() ---@type stl.t.T
  stl.reporter.info({
    from = self.fullname,
    subject = "print",
    details = { present = present, stack = stack },
  })
end

---@param element                       stl.t.T
---@return nil
function M:push(element)
  local present = self._present ---@type integer
  local stack = self._stack ---@type stl.c.CircularStack
  local el_present = stack:at(present) ---@type stl.t.T|nil
  if el_present ~= nil and self.equals(el_present, element) then
    return
  end

  if present < stack:size() then
    local el_next = stack:at(present + 1) ---@type stl.t.T
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

---@param filter                        stl.t.IFilter
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

---@return stl.t.T|nil
---@return integer
function M:top()
  local stack = self._stack ---@type stl.c.CircularStack
  return stack:top(), stack:size()
end

---@param element                       stl.t.T
---@return nil
function M:update_top(element)
  local stack = self._stack ---@type stl.c.CircularStack
  local present = stack:size()
  self._present = present
  stack:update(present, element)
end

return M
