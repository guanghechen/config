local __module_name__ = "ark.c.history" ---@type string

---@class ark.c.IHistory
---@field public name                   string
---@field public equals                 ark.t.IEquals
---@field public at                     fun(self: ark.c.IHistory, index: integer): ark.t.T|nil
---@field public backward               fun(self: ark.c.IHistory, step?: integer): ark.t.T|nil, boolean
---@field public bottom                 fun(self: ark.c.IHistory): ark.t.T|nil
---@field public capacity               fun(self: ark.c.IHistory): integer
---@field public clear                  fun(self: ark.c.IHistory): nil
---@field public collect                fun(self: ark.c.IHistory): ark.t.T[]
---@field public dump                   fun(self: ark.c.IHistory): ark.c.history.ISerializedData
---@field public fork                   fun(self: ark.c.IHistory, params: ark.c.history.IForkParams): ark.c.IHistory
---@field public forward                fun(self: ark.c.IHistory, step?: integer): ark.t.T|nil, boolean
---@field public go                     fun(self: ark.c.IHistory, index: integer): ark.t.T|nil, integer
---@field public is_bottom              fun(self: ark.c.IHistory): boolean
---@field public is_empty               fun(self: ark.c.IHistory): boolean
---@field public is_top                 fun(self: ark.c.IHistory): boolean
---@field public iterator               fun(self: ark.c.IHistory): fun(): ark.t.T|nil, integer|nil
---@field public iterator_reverse       fun(self: ark.c.IHistory): fun(): ark.t.T|nil, integer|nil
---@field public load                   fun(self: ark.c.IHistory, data: ark.c.history.ISerializedData): nil
---@field public present                fun(self: ark.c.IHistory): ark.t.T|nil, integer
---@field public print                  fun(self: ark.c.IHistory): nil
---@field public push                   fun(self: ark.c.IHistory, element: ark.t.T): nil
---@field public rearrange              fun(self: ark.c.IHistory, filter: ark.t.IFilter): nil
---@field public size                   fun(self: ark.c.IHistory): integer
---@field public top                    fun(self: ark.c.IHistory): ark.t.T|nil, integer
---@field public update_top             fun(self: ark.c.IHistory, element: ark.t.T): nil

---@class ark.c.history.IForkParams
---@field public name                   ?string

---@class ark.c.history.ISerializedData
---@field public present                integer
---@field public stack                  ark.t.T[]

---@class ark.c.history.IDeserializeProps
---@field public data                   ark.c.history.ISerializedData
---@field public name                   string
---@field public capacity               integer
---@field public equals                 ?ark.t.IEquals

---@class ark.c.history.IProps
---@field public name                   string
---@field public capacity               integer
---@field public equals                 ?ark.t.IEquals

---@class ark.c.History : ark.c.IHistory
---@field public fullname               string
---@field public equals                 ark.t.IEquals
---@field protected _present            integer
---@field protected _stack              ark.c.ICircularStack
local M = {}
M.__index = M

---@param props                         ark.c.history.IProps
---@return ark.c.History
function M.new(props)
  local name = props.name ---@type string
  local fullname = string.format("%s -> %s", name, __module_name__) ---@type string
  local capacity = props.capacity ---@type integer
  local equals = props.equals or ark.fn.equals_shallow ---@type ark.t.IEquals

  local self = setmetatable({}, M)
  self.fullname = fullname
  self.equals = equals
  self._present = 0
  self._stack = ark.c.CircularStack.new({ capacity = capacity })
  return self
end

---@param props                         ark.c.history.IDeserializeProps
---@return ark.c.History
function M.deserialize(props)
  local name = props.name ---@type string
  local fullname = string.format("%s -> %s", name, __module_name__) ---@type string
  local data = props.data ---@type ark.c.history.ISerializedData

  local self = setmetatable({}, M)
  self.fullname = fullname
  self.equals = props.equals or ark.fn.equals_shallow ---@type ark.t.IEquals
  self._stack = ark.c.CircularStack.from_array(data.stack, props.capacity)
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

---@return ark.c.history.ISerializedData
function M:dump()
  ---@type ark.c.history.ISerializedData
  return {
    present = self._present,
    stack = self._stack:collect(),
  }
end

---@param params                        ark.c.history.IForkParams
---@return ark.c.History
function M:fork(params)
  local name = params.name ---@type string
  local fullname = string.format("%s -> %s", name, __module_name__) ---@type string

  local instance = setmetatable({}, M)
  instance.fullname = fullname
  instance.equals = self.equals
  instance._present = self._present
  instance._stack = ark.c.CircularStack.from(self._stack)
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
  local stack = self._stack ---@type ark.c.ICircularStack
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
  local stack = self._stack ---@type ark.c.ICircularStack
  return stack:iterator()
end

---@return fun(): ark.t.T, integer
function M:iterator_reverse()
  local stack = self._stack ---@type ark.c.ICircularStack
  return stack:iterator_reverse()
end

---@param data                          ark.c.history.ISerializedData
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
  local present = self._present ---@type integer
  local stack = self._stack ---@type ark.c.ICircularStack
  local el_present = stack:at(present) ---@type ark.t.T|nil
  if el_present ~= nil and self.equals(el_present, element) then
    return
  end

  if present < stack:size() then
    local el_next = stack:at(present + 1) ---@type ark.t.T
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

---@param filter                        ark.t.IFilter
---@return nil
function M:rearrange(filter)
  local stack = self._stack ---@type ark.c.ICircularStack
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
  local stack = self._stack ---@type ark.c.ICircularStack
  return stack:top(), stack:size()
end

---@param element                       ark.t.T
---@return nil
function M:update_top(element)
  local stack = self._stack ---@type ark.c.ICircularStack
  local present = stack:size()
  self._present = present
  stack:update(present, element)
end

return M
