---@class fml.collection.CircularQueue : fml.types.collection.ICircularQueue
---@field private _elements             fml.types.T[]
---@field private _capacity             number
---@field private _size                 number
---@field private _start                number
---@field private _end                  number
local M = {}
M.__index = M

---@class fml.collection.ICircularQueueProps
---@field public capacity               number

---@param props fml.collection.ICircularQueueProps
---@return fml.collection.CircularQueue
function M.new(props)
  local self = setmetatable({}, M)

  self._elements = {}
  self._size = 0
  self._start = 1
  self._end = 0
  self._capacity = props.capacity

  return self
end

---@return number
function M:size()
  return self._size
end

---@return fml.types.T[]
function M:collect()
  local _capacity = self._capacity
  local _elements = self._elements
  local _start = self._start
  local _size = self._size
  local id = _start - 1
  local result = {}

  ---@diagnostic disable-next-line: unused-local
  for i = 1, _size do
    id = id + 1
    if id > _capacity then
      id = 1
    end
    table.insert(result, _elements[id])
  end
  return result
end

---@param index number
---@return fml.types.T|nil
function M:at(index)
  if index < 1 or index > self._size then
    return nil
  end

  local idx = self._start + index - 1 ---@type number
  if idx > self._capacity then
    idx = idx - self._capacity
  end
  return self._elements[idx]
end

---@return fml.types.T|nil
function M:front()
  if self._size > 0 then
    return self._elements[self._start]
  end
end

---@return fml.types.T|nil
function M:back()
  if self._size > 0 then
    return self._elements[self._end]
  end
end

---@param element fml.types.T
---@return nil
function M:enqueue(element)
  self._end = self._end + 1
  if self._end > self._capacity then
    self._end = 1
  end
  self._elements[self._end] = element

  if self._size < self._capacity then
    self._size = self._size + 1
  else
    self._start = self._start + 1
    if self._start > self._capacity then
      self._start = 1
    end
  end
end

---@return fml.types.T|nil
function M:dequeue()
  if self._size < 1 then
    return nil
  end

  local target = self._elements[self._start]
  if self._size == 1 then
    self._size = 0
    self._start = 1
    self._end = 0
  else
    self._size = self._size - 1
    self._start = self._start + 1
    if self._start > self._capacity then
      self._start = 1
    end
  end
  return target
end

---@return fml.types.T|nil
function M:dequeue_back()
  if self._size < 1 then
    return nil
  end

  local target = self._elements[self._start]
  if self._size == 1 then
    self._size = 0
    self._start = 1
    self._end = 0
  else
    self._size = self._size - 1
    self._end = self._end - 1
    if self._end < 1 then
      self._end = self._capacity
    end
  end
  return target
end

function M:iterator()
  local _capacity = self._capacity
  local _elements = self._elements
  local _start = self._start
  local _size = self._size
  local i = 0
  local id = _start - 1

  return function()
    i = i + 1
    if i <= _size then
      id = id + 1
      if id > _capacity then
        id = 1
      end
      return _elements[id], i
    end
  end
end

function M:iterator_reverse()
  local _capacity = self._capacity
  local _elements = self._elements
  local _end = self._end
  local _size = self._size
  local i = _size + 1
  local id = _end + 1

  return function()
    i = i - 1
    if i > 0 then
      id = id - 1
      if id < 1 then
        id = _capacity
      end
      return _elements[id], i
    end
  end
end

return M
