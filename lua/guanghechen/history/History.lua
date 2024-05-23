local CircularQueue = require("guanghechen.queue.CircularQueue")

---@class guanghechen.history.History: guanghechen.types.IHistory
---@field private _comparator fun(x:guanghechen.types.T, y:guanghechen.types.T): number
---@field private _name string
---@field private _present_idx number
---@field private _stack guanghechen.types.ICircularQueue
local History = {}
History.__index = History

---@param opts { name: string, max_count: number, comparator: fun(x:guanghechen.types.T, y:guanghechen.types.T): number}
function History.new(opts)
  local self = setmetatable({}, History)

  self._name = opts.name ---@type string
  self._comparator = opts.comparator
  self._present_idx = 0 ---@type number
  self._stack = CircularQueue.new({ capacity = opts.max_count }) ---@type guanghechen.types.ICircularQueue

  return self
end

---@return string
function History:name()
  return self._name
end

---@return guanghechen.types.T|nil
function History:present()
  return self._stack:at(self._present_idx)
end

---@return number
function History:present_index()
  return self._present_idx
end

---@param step? number
---@return guanghechen.types.T|nil
function History:back(step)
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
---@return guanghechen.types.T|nil
function History:forward(step)
  if step == nil or step < 1 then
    step = 1
  end

  local idx = self._present_idx + step ---@type number
  local stack = self._stack ---@type guanghechen.types.ICircularQueue
  if idx > stack:size() then
    idx = stack:size()
  end

  self._present_idx = idx
  return stack:at(idx)
end

---@param index number
---@return guanghechen.types.T|nil
function History:go(index)
  local idx = index ---@type number
  local stack = self._stack ---@type guanghechen.types.ICircularQueue
  if idx > 0 and idx <= stack:size() then
    self._present_idx = idx
    return stack:at(idx)
  end
  return nil
end

---@param element guanghechen.types.T
---@return nil
function History:push(element)
  local idx = self._present_idx ---@type number
  local stack = self._stack ---@type guanghechen.types.ICircularQueue
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

function History:iterator()
  return self._stack:iterator()
end

function History:iterator_reverse()
  return self._stack:iterator_reverse()
end

function History:print()
  local stack = self._stack:collect() ---@type guanghechen.types.T[]
  vim.notify(vim.inspect({ stack = stack, present_index = self._present_idx }))
end

return History
