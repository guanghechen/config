local reporter = require("fml.std.reporter")
local CircularQueue = require("fml.collection.circular_queue")

---@class fml.collection.History : fml.types.collection.IHistory
---@field private _stack                fml.types.collection.ICircularQueue
---@field private _max_count            integer
---@field private _present_idx          integer
local M = {}
M.__index = M

---@class fml.collection.History.IProps
---@field public name                   string
---@field public validate               fun(v: fml.types.T): boolean
---@field public comparator             fun(x: fml.types.T, y: fml.types.T): integer
---@field public max_count              integer

---@param props                         fml.collection.History.IProps
---@return fml.collection.History
function M.new(props)
  local self = setmetatable({}, M)

  self.name = props.name
  self.comparator = props.comparator
  self.validate = props.validate
  self._stack = CircularQueue.new({ capacity = props.max_count })
  self._max_count = props.max_count
  self._present_idx = 0

  return self
end

---@param new_name                      ?string
---@return fml.collection.History
function M:clone(new_name)
  local history = M.new({
    name = new_name or self.name,
    validate = self.validate,
    comparator = self.comparator,
    max_count = 0,
  })
  history._stack = self._stack:clone()
  history:go(self._present_idx)
  return history
end

---@param step                          ?number
---@return fml.types.T|nil
function M:back(step)
  step = math.max(1, step or 1)
  for _ = 1, step, 1 do
    local present = self:present()
    if present == nil then
      return nil
    end
    self._present_idx = self._present_idx - 1
  end
  return self:present()
end

---@return nil
function M:clear()
  self._present_idx = 0
  self._stack:clear()
end

---@return boolean
function M:empty()
  return self:present() == nil
end

---@param step                          ?number
---@return fml.types.T|nil
function M:forward(step)
  step = math.max(1, step or 1)
  for _ = 1, step, 1 do
    local present = self:present()
    if present == nil then
      return nil
    end
    if self._present_idx == self._stack:size() then
      break
    end
    self._present_idx = self._present_idx + 1
  end
  return self:present()
end

---@param idx                           integer
---@return fml.types.T|nil
function M:go(idx)
  idx = math.max(1, math.min(self._stack:size(), idx))
  self._present_idx = idx
  return self._stack:at(idx)
end

function M:iterator()
  local iterator = self._stack:iterator()

  local i = 0
  return function()
    while true do
      i = i + 1
      local element = iterator()
      if element == nil then
        return nil
      end
      if self.validate(element) then
        return element, i
      end
    end
  end
end

function M:iterator_reverse()
  local size = self._stack:size() ---@type integer
  local iterator = self._stack:iterator_reverse()

  local i = size + 1
  return function()
    while true do
      i = i - 1
      local element = iterator()
      if element == nil then
        return nil
      end
      if self.validate(element) then
        return element, i
      end
    end
  end
end

---@return fml.types.T|nil
function M:present()
  while self._present_idx > 0 do
    local present = self._stack:at(self._present_idx)
    if present == nil or self.validate(present) then
      return present
    end
    self._present_idx = self._present_idx - 1
  end
  return nil
end

---@return integer
function M:present_index()
  return self._present_idx
end

---@return nil
function M:print()
  local history = {} ---@type fml.types.T[]
  for element in self._stack:iterator() do
    if self.validate(element) then
      table.insert(history, element)
    end
  end
  reporter.info({
    from = "fml.collection.history",
    subject = "print",
    message = "History",
    details = { history = history },
  })
end

---@param element                       fml.types.T
---@return nil
function M:push(element)
  local idx = self._present_idx ---@type number
  local stack = self._stack ---@type fml.types.collection.ICircularQueue
  local top = stack:at(idx)
  if top ~= nil and self.comparator(top, element) == 0 or not self.validate(element) then
    return
  end

  idx = idx + 1
  if idx <= stack:size() then
    local delta = self.comparator(stack:at(idx), element)
    if delta ~= 0 then
      while stack:size() >= idx do
        stack:dequeue_back()
      end
      stack:enqueue(element)
    end
    self._present_idx = idx
  else
    stack:enqueue(element)
    self._present_idx = stack:size()
  end
  self:present()
end

return M
