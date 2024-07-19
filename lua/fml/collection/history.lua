local CircularQueue = require("fml.collection.circular_queue")
local reporter = require("fml.std.reporter")

---@class fml.collection.History : fml.types.collection.IHistory
---@field private _present_idx          integer
---@field private _stack                fml.types.collection.ICircularQueue
local M = {}
M.__index = M

---@param x                             fml.types.T
---@param y                             fml.types.T
---@return boolean
local function default_equals(x, y)
  return x == y
end

---@param x                             fml.types.T
---@return boolean
---@diagnostic disable-next-line: unused-local
local function default_validate(x)
  return true
end

---@class fml.collection.history.IProps
---@field public name                   string
---@field public capacity               integer
---@field public equals                 ?fun(x: fml.types.T, y: fml.types.T): boolean
---@field public validate               ?fun(v: fml.types.T): boolean

---@class fml.collection.history.IDeserializeProps
---@field public data                   fml.types.collection.history.ISerializedData
---@field public name                   string
---@field public capacity               integer
---@field public equals                 ?fun(x: fml.types.T, y: fml.types.T): boolean
---@field public validate               ?fun(v: fml.types.T): boolean

---@param props                         fml.collection.history.IProps
---@return fml.collection.History
function M.new(props)
  local capacity = math.max(1, props.capacity) ---@type integer

  local self = setmetatable({}, M)
  self.name = props.name
  self.capacity = capacity
  self.equals = props.equals or default_equals
  self.validate = props.validate or default_validate
  self._present_idx = 0
  self._stack = CircularQueue.new({ capacity = capacity })
  return self
end

---@param props                         fml.collection.history.IDeserializeProps
---@return fml.collection.History
function M.deserialize(props)
  local capacity = math.max(1, props.capacity) ---@type integer
  local data = props.data ---@type fml.types.collection.history.ISerializedData

  local self = setmetatable({}, M)
  self.name = props.name
  self.capacity = capacity
  self.equals = props.equals or default_equals
  self.validate = props.validate or default_validate
  self._present_idx = data.present_index
  self._stack = CircularQueue.from_array(data.stack, capacity)
  return self
end

---@param step                          ?integer
---@return fml.types.T|nil
function M:back(step)
  step = math.max(1, step or 1)
  local idx = self._present_idx ---@type integer

  for _ = 1, step, 1 do
    while idx > 0 do
      local present = self._stack:at(idx) ---@type fml.types.T|nil
      if self.validate(present) then
        break
      end
      idx = idx - 1
    end
    idx = idx - 1
  end

  self._present_idx = math.max(idx, 0)
  return self:present()
end

---@return nil
function M:clear()
  self._present_idx = 0
  self._stack:clear()
end

---@return fml.types.collection.history.ISerializedData
function M:dump()
  self:rearrange()
  return {
    present_index = self._present_idx,
    stack = self._stack:collect(),
  }
end

---@return boolean
function M:empty()
  self:rearrange()
  return self._stack:size() == 0
end

---@param params                        ?fml.types.collection.history.IForkParams
---@return fml.collection.History
function M:fork(params)
  self:rearrange()

  local new_name = params and params.name or self.name
  local instance = setmetatable({}, M)
  instance.name = new_name
  instance.equals = self.equals
  instance.validate = self.validate
  instance._present_idx = self._present_idx
  instance._stack = self._stack:fork(function()
    return true
  end)

  return instance
end

---@param step                          ?number
---@return fml.types.T|nil
function M:forward(step)
  step = math.max(1, step or 1)
  local idx = self._present_idx ---@type integer

  for _ = 1, step, 1 do
    idx = idx + 1
    while idx <= self._stack:size() do
      local present = self._stack:at(idx) ---@type fml.types.T|nil
      if self.validate(present) then
        break
      end
      idx = idx + 1
    end
  end

  self._present_idx = math.min(idx, self._stack:size())
  return self:present()
end

---@param idx                           integer
---@return fml.types.T|nil
function M:go(idx)
  idx = math.min(idx, self._stack:size())
  idx = math.max(idx, self._stack:size() > 0 and 1 or 0)
  self._present_idx = idx
  return self:present()
end

function M:iterator()
  self:rearrange()

  local i = 0 ---@type integer
  return function()
    i = i + 1
    if i <= self._stack:size() then
      return self._stack:at(i), i
    end
  end
end

function M:iterator_reverse()
  self:rearrange()

  local i = self._stack:size() + 1 ---@type integer
  return function()
    i = i - 1
    if i > 0 then
      return self._stack:at(i), i
    end
  end
end

---@param data                          fml.types.collection.history.ISerializedData
---@return nil
function M:load(data)
  local stack = data.stack ---@type fml.types.T[]
  local present_index = data.present_index ---@type integer
  self._present_index = present_index
  self._stack:reset(stack)
end

---@return fml.types.T|nil
function M:present()
  local idx = self._present_idx
  while idx > 0 do
    local present = self._stack:at(idx) ---@type fml.types.T|nil
    if self.validate(present) then
      break
    end
    idx = idx - 1
  end

  if idx > 0 then
    self._present_idx = idx
    return self._stack:at(idx)
  end

  self:rearrange()
  self._present_idx = self._stack:size() > 0 and 1 or 0
  return self._stack:at(self._present_idx)
end

function M:present_index()
  self:rearrange()
  return self._present_idx
end

---@return nil
function M:print()
  self:rearrange()

  local present_index = self._present_idx ---@type integer
  local present = self._stack:at(self._present_idx) ---@type fml.types.T|nil
  local history = self._stack:collect()

  reporter.info({
    from = "fml.collection.history",
    subject = "print",
    message = "History",
    details = { present_index = present_index, present = present, history = history },
  })
end

---@param element                       fml.types.T
---@return nil
function M:push(element)
  if not self.validate(element) then
    return
  end

  self:rearrange()
  if self._stack:size() < 1 then
    self._stack:enqueue(element)
    self._present_idx = 1
    return
  end

  if self.equals(self._stack:at(self._present_idx), element) then
    return
  end

  while self._stack:size() > self._present_idx do
    self._stack:dequeue_back()
  end
  self._stack:enqueue(element)
  self._present_idx = self._stack:size()
end

function M:rearrange()
  local old_present_index = self._present_idx ---@type integer
  local new_present_index = 0 ---@type integer
  local not_matched = true ---@type boolean
  local idx = 0 ---@type integer

  self._stack:rearrange(function(element, index)
    if self.validate(element) then
      idx = idx + 1
      if index < old_present_index then
        new_present_index = idx
      elseif not_matched then
        not_matched = false
        new_present_index = index == old_present_index and idx or idx - 1
      end
      return true
    end
    return false
  end)

  if new_present_index == 0 and self._stack:size() > 0 then
    new_present_index = 1
  end
  self._present_idx = math.max(new_present_index, self._stack:size() > 0 and 1 or 0)
end

return M
