---@class guanghechen.queue.CircularQueue : guanghechen.types.ICircularQueue
---@field private _elements guanghechen.types.T[]
---@field private _capacity number
---@field private _size number
---@field private _start number
---@field private _end number
local CircularQueue = {}
CircularQueue.__index = CircularQueue

---@param opts {capacity: number}
function CircularQueue.new(opts)
  local self = setmetatable({}, CircularQueue)

  self._elements = {}
  self._size = 0
  self._start = 1
  self._end = 0
  self._capacity = opts.capacity

  return self
end

---@return number
function CircularQueue:size()
  return self._size
end

---@return guanghechen.types.T|nil
function CircularQueue:front()
  if self._size < 1 then
    return nil
  else
    return self._elements[self._start]
  end
end

---@return guanghechen.types.T|nil
function CircularQueue:back()
  if self._size < 1 then
    return nil
  else
    return self._elements[self._end]
  end
end

---@param element guanghechen.types.T
---@return nil
function CircularQueue:enqueue(element)
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

---@return guanghechen.types.T|nil
function CircularQueue:dequeue()
  if self._size < 1 then
    return nil
  end

  local target = self._elements[self._start]
  if self._size == 1 then
    self._size = 0
    self._start = 1
    self._end = 0
    return target
  end

  self._size = self._size - 1
  self._start = self._start + 1
  if self._start > self._capacity then
    self._start = 1
  end
end

function CircularQueue:iterator()
  local _capacity = self._capacity
  local _elements = self._elements
  local _start = self._start
  local _size = self._size
  local i = 0
  local id = _start - 1

  return function()
    i = i + 1
    id = id + 1
    if i <= _size then
      if id > _capacity then
        id = 1
      end
      return _elements[id]
    end
  end
end

function CircularQueue:iterator_reverse()
  local _capacity = self._capacity
  local _elements = self._elements
  local _end = self._end
  local _size = self._size
  local i = 0
  local id = _end + 1

  return function()
    i = i + 1
    id = id - 1
    if i <= _size then
      if id < 1 then
        id = _capacity
      end
      return _elements[id]
    end
  end
end
