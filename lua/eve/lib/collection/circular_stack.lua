---@class eve.lib.collection.ICircularStack
---@field public capacity               fun(self: eve.lib.collection.ICircularStack): integer
---@field public size                   fun(self: eve.lib.collection.ICircularStack): integer
---@field public at                     fun(self: eve.lib.collection.ICircularStack, index: integer): eve.t.T|nil
---@field public clear                  fun(self: eve.lib.collection.ICircularStack): nil
---@field public collect                fun(self: eve.lib.collection.ICircularStack): eve.t.T[]
---@field public count                  fun(self: eve.lib.collection.ICircularStack, filter: eve.t.IFilter): integer
---@field public fork                   fun(self: eve.lib.collection.ICircularStack, filter: eve.t.IFilter): eve.lib.collection.ICircularStack
---@field public iterator               fun(self: eve.lib.collection.ICircularStack): fun(): eve.t.T|nil
---@field public iterator_reverse       fun(self: eve.lib.collection.ICircularStack): fun(): eve.t.T|nil
---@field public pop                    fun(self: eve.lib.collection.ICircularStack): eve.t.T|nil
---@field public push                   fun(self: eve.lib.collection.ICircularStack, element: eve.t.T): nil
---@field public rearrange              fun(self: eve.lib.collection.ICircularStack, filter: eve.t.IFilter): fun(): eve.t.T|nil
---@field public reset                  fun(self: eve.lib.collection.ICircularStack, elements: eve.t.T[]): boolean): fun(): eve.t.T|nil
---@field public top                    fun(self: eve.lib.collection.ICircularStack): eve.t.T|nil
---@field public update                 fun(self: eve.lib.collection.ICircularStack, index: integer, value: eve.t.T): nil

---@class eve.lib.collection.circular_stack.IProps
---@field public capacity               integer

local _tmp_array = {} ---@type eve.t.T[]

---@class eve.lib.collection.CircularStack : eve.lib.collection.ICircularStack
---@field private _elements             eve.t.T[]
---@field private _capacity             integer
---@field private _size                 integer
---@field private _start                integer
---@field private _end                  integer
local M = {}
M.__index = M

---@param props                         eve.lib.collection.circular_stack.IProps
---@return eve.lib.collection.CircularStack
function M.new(props)
  local capacity = math.max(1, props.capacity) ---@type integer

  local self = setmetatable({}, M)
  self._elements = {}
  self._capacity = capacity
  self._size = 0
  self._start = 1
  self._end = 0
  return self
end

---@param queue                         eve.lib.collection.ICircularStack
---@return eve.lib.collection.CircularStack
function M.from(queue)
  local elements = {} ---@type eve.t.T[]
  local size = 0 ---@type integer
  for element in queue:iterator() do
    size = size + 1
    elements[size] = element
  end

  local self = setmetatable({}, M)
  self._elements = elements
  self._capacity = queue:capacity()
  self._size = size
  self._start = 1
  self._end = size
  return self
end

---@param arr                          eve.t.T[]
---@param capacity                     integer
---@return eve.lib.collection.CircularStack
function M.from_array(arr, capacity)
  capacity = math.max(1, capacity) ---@type integer
  local elements = {} ---@type eve.t.T[]
  local size = 0 ---@type integer
  local arr_start = #arr <= capacity and 1 or #arr - capacity + 1 ---@type integer
  for idx = arr_start, #arr, 1 do
    size = size + 1
    elements[size] = arr[idx]
  end

  local self = setmetatable({}, M)
  self._elements = elements
  self._capacity = capacity
  self._size = size
  self._start = 1
  self._end = size
  return self
end

---@return integer
function M:capacity()
  return self._capacity
end

---@return integer
function M:size()
  return self._size
end

---@param index                         integer
---@return eve.t.T|nil
function M:at(index)
  if index < 1 or index > self._size then
    return
  end

  local idx = self._start + index - 1 ---@type integer
  idx = idx <= self._capacity and idx or idx - self._capacity ---@type integer
  return self._elements[idx]
end

---@return nil
function M:clear()
  self._size = 0
  self._start = 1
  self._end = 0
end

---@return eve.t.T[]
function M:collect()
  local elements = self._elements ---@type eve.t.T[]
  local capacity = self._capacity ---@type integer
  local size = self._size ---@type integer

  local results = {} ---@type eve.t.T[]
  local idx = self._start - 1 ---@type integer

  for index = 1, size, 1 do
    idx = idx == capacity and 1 or idx + 1 ---@type integer
    results[index] = elements[idx]
  end
  return results
end

---@param filter                        eve.t.IFilter
---@return integer
function M:count(filter)
  local elements = self._elements ---@type eve.t.T[]
  local capacity = self._capacity ---@type integer
  local size = self._size ---@type integer

  local count = 0 ---@type integer
  local idx = self._start - 1 ---@type integer

  for index = 1, size, 1 do
    idx = idx == capacity and 1 or idx + 1
    if filter(elements[idx], index) then
      count = count + 1
    end
  end
  return count
end

---@param filter                        fun(element: eve.t.T, index: integer): boolean
---@return eve.lib.collection.CircularStack
function M:fork(filter)
  self:rearrange(filter)
  return M.from(self)
end

---@return fun(): eve.t.T|nil, integer|nil
function M:iterator()
  local elements = self._elements ---@type eve.t.T[]
  local capacity = self._capacity ---@type integer
  local size = self._size ---@type integer

  local index = 0 ---@type integer
  local idx = self._start - 1 ---@type integer

  ---@return eve.t.T|nil
  ---@return integer|nil
  return function()
    index = index + 1
    if index <= size then
      idx = idx == capacity and 1 or idx + 1
      return elements[idx], index
    end
  end
end

---@return fun(): eve.t.T|nil, integer|nil
function M:iterator_reverse()
  local elements = self._elements ---@type eve.t.T[]
  local capacity = self._capacity ---@type integer
  local size = self._size ---@type integer

  local index = size + 1 ---@type integer
  local idx = self._end + 1 ---@type integer

  ---@return eve.t.T|nil
  ---@return integer|nil
  return function()
    index = index - 1
    if index > 0 then
      idx = idx == 1 and capacity or idx - 1
      return elements[idx], index
    end
  end
end

---@return eve.t.T|nil
function M:pop()
  if self._size < 1 then
    return nil
  end

  local target = self._elements[self._end] ---@type eve.t.T|nil
  if self._size == 1 then
    self._size = 0
    self._start = 1
    self._end = 0
  else
    self._size = self._size - 1
    self._end = self._end == 1 and self._capacity or self._end - 1
  end
  return target
end

---@param element                       eve.t.T
---@return nil
function M:push(element)
  self._end = self._end == self._capacity and 1 or self._end + 1
  self._elements[self._end] = element

  if self._size < self._capacity then
    self._size = self._size + 1
  else
    self._start = self._start == self._capacity and 1 or self._start + 1
  end
end

---@param filter                        eve.t.IFilter
---@return nil
function M:rearrange(filter)
  if self._size < 1 then
    self._size = 0
    self._start = 1
    self._end = 0
    return
  end

  if self._start <= self._end then
    local size = 0 ---@type integer
    local idx = self._start - 1 ---@type integer
    for index = 1, self._size, 1 do
      idx = idx + 1
      local element = self._elements[idx] ---@type eve.t.T
      if filter(element, index) then
        size = size + 1
        self._elements[size] = element
      end
    end
    self._size = size
    self._start = 1
    self._end = size
    return
  end

  local size = 0 ---@type integer
  local index = 0 ---@type integer
  for idx = 1, self._end, 1 do
    _tmp_array[idx] = self._elements[idx]
  end
  for idx = self._start, self._capacity, 1 do
    index = index + 1
    local element = self._elements[idx] ---@type eve.t.T
    if filter(element, index) then
      size = size + 1
      self._elements[size] = element
    end
  end
  for idx = 1, self._end, 1 do
    index = index + 1
    local element = _tmp_array[idx] ---@type eve.t.T
    if filter(element, index) then
      size = size + 1
      self._elements[size] = element
    end
  end
  self._size = size
  self._start = 1
  self._end = size
end

---@param arr                           eve.t.T[]
---@return nil
function M:reset(arr)
  local capacity = self._capacity ---@type integer
  local elements = self._elements ---@type eve.t.T[]
  local size = 0 ---@type integer
  local arr_start = #arr <= capacity and 1 or #arr - capacity + 1 ---@type integer
  for idx = arr_start, #arr, 1 do
    size = size + 1
    elements[size] = arr[idx]
  end

  self._size = size
  self._start = 1
  self._end = size
end

---@return eve.t.T|nil
function M:top()
  return self._size > 0 and self._elements[self._end] or nil
end

---@param index                         integer
---@param value                         eve.t.T
---@return nil
function M:update(index, value)
  if index < 1 or index > self._size then
    return
  end

  local idx = self._start + index - 1 ---@type integer
  idx = idx <= self._capacity and idx or idx - self._capacity ---@type integer
  self._elements[idx] = value
end

return M
