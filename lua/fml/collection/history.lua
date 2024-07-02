local CircularQueue = require("fml.collection.circular_queue")

---@class fml.collection.History : fml.types.collection.IHistory
---@field private _comparator           fun(x: fml.types.T, y: fml.types.T): number
---@field private _name                 string
---@field private _present_idx          number
---@field private _stack                fml.types.collection.ICircularQueue
local M = {}
M.__index = M

---@class fml.collection.History.IProps
---@field public name                   string
---@field public max_count              number
---@field public comparator             fun(x: fml.types.T, y: fml.types.T): number

---@param props fml.collection.History.IProps
---@return fml.collection.History
function M.new(props)
  local self = setmetatable({}, M)

  self._name = props.name
  self._comparator = props.comparator
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
  return self._stack:at(self._present_idx)
end

---@return integer
function M:present_index()
  return self._present_idx
end

function M:clear()
  self._present_idx = 0
  self._stack:clear()
end

---@param step? number
---@return fml.types.T|nil
function M:back(step)
  if step == nil or step < 1 then
    step = 1
  end

  local idx = self._present_idx - step ---@type number
  if idx < 1 then
    idx = 1
  end

  self._present_idx = idx
  return self._stack:at(idx)
end

---@param step? number
---@return fml.types.T|nil
function M:forward(step)
  if step == nil or step < 1 then
    step = 1
  end

  local idx = self._present_idx + step ---@type number
  local stack = self._stack ---@type fml.types.collection.ICircularQueue
  if idx > stack:size() then
    idx = stack:size()
  end

  self._present_idx = idx
  return stack:at(idx)
end

---@param index number
---@return fml.types.T|nil
function M:go(index)
  local idx = index ---@type number
  local stack = self._stack ---@type fml.types.collection.ICircularQueue
  if idx > 0 and idx <= stack:size() then
    self._present_idx = idx
    return stack:at(idx)
  end
  return nil
end

---@param element fml.types.T
---@return nil
function M:push(element)
  local idx = self._present_idx ---@type number
  local stack = self._stack ---@type fml.types.collection.ICircularQueue
  local top = stack:at(idx)
  if top ~= nil and self._comparator(top, element) == 0 then
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
end

function M:iterator()
  return self._stack:iterator()
end

function M:iterator_reverse()
  return self._stack:iterator_reverse()
end

---@return nil
function M:print()
  local stack = self._stack:collect() ---@type fml.types.T[]
  vim.notify(vim.inspect({ stack = stack, present_index = self._present_idx }))
end

return M
