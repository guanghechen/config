local CircularQueue = require("fml.collection.circular_queue")

---@class fml.collection.History : fml.types.collection.IHistory
---@field private _comparator           fun(x: fml.types.T, y: fml.types.T): number
---@field private _validate             fun(v: fml.types.T): boolean
---@field private _name                 string
---@field private _present_idx          number
---@field private _stack                fml.types.collection.ICircularQueue
local M = {}
M.__index = M

---@class fml.collection.History.IProps
---@field public name                   string
---@field public max_count              number
---@field public comparator             fun(x: fml.types.T, y: fml.types.T): number
---@field public validate               fun(v: fml.types.T): boolean

---@param props fml.collection.History.IProps
---@return fml.collection.History
function M.new(props)
  local self = setmetatable({}, M)

  self._name = props.name
  self._comparator = props.comparator
  self._validate = props.validate
  self._present_idx = 0
  self._stack = CircularQueue.new({ capacity = props.max_count })

  return self
end

---@return string
function M:name()
  return self._name
end

---@return fml.types.T|nil
function M:present()
  while self._present_idx > 0 do
    local present = self._stack:at(self._present_idx)
    if present == nil or self._validate(present) then
      return present
    end
    self._present_idx = self._present_idx - 1
  end
  return nil
end

---@return integer
function M:present_index()
  self:present()
  return self._present_idx
end

function M:clear()
  self._present_idx = 0
  self._stack:clear()
end

---@param step? number
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

---@param step? number
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

---@param element fml.types.T
---@return nil
function M:push(element)
  local idx = self._present_idx ---@type number
  local stack = self._stack ---@type fml.types.collection.ICircularQueue
  local top = stack:at(idx)
  if top ~= nil and self._comparator(top, element) == 0 or not self.validate(element) then
    return
  end

  idx = idx + 1
  if idx <= stack:size() then
    local delta = self._comparator(stack:at(idx), element)
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

function M:iterator()
  local iterator = self._stack:iterator()

  local i = 0
  return function()
    while true do
      local element = iterator()
      if element == nil then
        return nil
      end
      if self:validate(element) then
        i = i + 1
        return element, i
      end
    end
  end
end

function M:iterator_reverse()
  ---@type integer
  local size = self._stack:count(function(element)
    return self:validate(element)
  end)

  local iterator = self._stack:iterator_reverse()

  local i = size + 1
  return function()
    while true do
      local element = iterator()
      if element == nil then
        return nil
      end
      if self:validate(element) then
        i = i - 1
        return element, i
      end
    end
  end
end

---@return nil
function M:print()
  local history = {} ---@type fml.types.T[]
  for element in self:iterator() do
    table.insert(history, element)
  end
  vim.notify(vim.inspect({ history = history }))
end

return M
