local __module_name__ = "eve.lib.collection.history" ---@type string

local reporter = require("eve.builtin.reporter")

local functional = require("eve.lib.functional")
local CircularStack = require("eve.lib.collection.circular_stack")

---@class eve.lib.collection.IHistory
---@field public name                   string
---@field public equals                 eve.t.IEquals
---@field public backward               fun(self: eve.lib.collection.IHistory, step?: integer): eve.t.T|nil, boolean
---@field public bottom                 fun(self: eve.lib.collection.IHistory): eve.t.T|nil
---@field public capacity               fun(self: eve.lib.collection.IHistory): integer
---@field public clear                  fun(self: eve.lib.collection.IHistory): nil
---@field public collect                fun(self: eve.lib.collection.IHistory): eve.t.T[]
---@field public dump                   fun(self: eve.lib.collection.IHistory): eve.lib.collection.history.ISerializedData
---@field public fork                   fun(self: eve.lib.collection.IHistory, params: eve.lib.collection.history.IForkParams): eve.lib.collection.IHistory
---@field public forward                fun(self: eve.lib.collection.IHistory, step?: integer): eve.t.T|nil, boolean
---@field public go                     fun(self: eve.lib.collection.IHistory, index: integer): eve.t.T|nil, integer
---@field public is_bottom              fun(self: eve.lib.collection.IHistory): boolean
---@field public is_empty               fun(self: eve.lib.collection.IHistory): boolean
---@field public is_top                 fun(self: eve.lib.collection.IHistory): boolean
---@field public iterator               fun(self: eve.lib.collection.IHistory): fun(): eve.t.T|nil, integer|nil
---@field public iterator_reverse       fun(self: eve.lib.collection.IHistory): fun(): eve.t.T|nil, integer|nil
---@field public load                   fun(self: eve.lib.collection.IHistory, data: eve.lib.collection.history.ISerializedData): nil
---@field public present                fun(self: eve.lib.collection.IHistory): eve.t.T|nil, integer
---@field public print                  fun(self: eve.lib.collection.IHistory): nil
---@field public push                   fun(self: eve.lib.collection.IHistory, element: eve.t.T): nil
---@field public rearrange              fun(self: eve.lib.collection.IHistory, filter: eve.t.IFilter): nil
---@field public size                   fun(self: eve.lib.collection.IHistory): integer
---@field public top                    fun(self: eve.lib.collection.IHistory): eve.t.T|nil, integer
---@field public update_top             fun(self: eve.lib.collection.IHistory, element: eve.t.T): nil

---@class eve.lib.collection.history.IForkParams
---@field public name                   ?string

---@class eve.lib.collection.history.ISerializedData
---@field public present                integer
---@field public stack                  eve.t.T[]

---@class eve.lib.collection.history.IDeserializeProps
---@field public data                   eve.lib.collection.history.ISerializedData
---@field public name                   string
---@field public capacity               integer
---@field public equals                 ?eve.t.IEquals

---@class eve.lib.collection.history.IProps
---@field public name                   string
---@field public capacity               integer
---@field public equals                 ?eve.t.IEquals

---@class eve.lib.collection.History : eve.lib.collection.IHistory
---@field public name                   string
---@field public equals                 eve.t.IEquals
---@field protected _present            integer
---@field protected _stack              eve.lib.collection.ICircularStack
local M = {}
M.__index = M

---@param props                         eve.lib.collection.history.IProps
---@return eve.lib.collection.History
function M.new(props)
  local name = props.name ---@type string
  local capacity = props.capacity ---@type integer
  local equals = props.equals or functional.equals_shallow ---@type eve.t.IEquals

  local self = setmetatable({}, M)
  self.name = name
  self.equals = equals
  self._present = 0
  self._stack = CircularStack.new({ capacity = capacity })
  return self
end

---@param props                         eve.lib.collection.history.IDeserializeProps
---@return eve.lib.collection.History
function M.deserialize(props)
  local data = props.data ---@type eve.lib.collection.history.ISerializedData

  local self = setmetatable({}, M)
  self.name = props.name
  self.equals = props.equals or functional.equals_shallow ---@type eve.t.IEquals
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

---@return eve.lib.collection.history.ISerializedData
function M:dump()
  ---@type eve.lib.collection.history.ISerializedData
  return {
    present = self._present,
    stack = self._stack:collect(),
  }
end

---@param params                        eve.lib.collection.history.IForkParams
---@return eve.lib.collection.History
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
  local stack = self._stack ---@type eve.lib.collection.ICircularStack
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
  local stack = self._stack ---@type eve.lib.collection.ICircularStack
  return stack:iterator()
end

---@return fun(): eve.t.T, integer
function M:iterator_reverse()
  local stack = self._stack ---@type eve.lib.collection.ICircularStack
  return stack:iterator_reverse()
end

---@param data                          eve.lib.collection.history.ISerializedData
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
    from = __module_name__,
    subject = "print",
    details = { present = present, stack = stack },
  })
end

---@param element                       eve.t.T
---@return nil
function M:push(element)
  local present = self._present ---@type integer
  local stack = self._stack ---@type eve.lib.collection.ICircularStack
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
  local stack = self._stack ---@type eve.lib.collection.ICircularStack
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
  local stack = self._stack ---@type eve.lib.collection.ICircularStack
  return stack:top(), stack:size()
end

---@param element                       eve.t.T
---@return nil
function M:update_top(element)
  local stack = self._stack ---@type eve.lib.collection.ICircularStack
  local present = stack:size()
  self._present = present
  stack:update(present, element)
end

return M
