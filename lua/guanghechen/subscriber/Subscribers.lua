local SafeBatchHandler = require("guanghechen.disposable.SafeBatchHandler")

---@class guanghechen.subscriber.Subscribers.util
local util = {
  misc = require("guanghechen.util.misc"),
}

---@class guanghechen.subscriber.Subscribers : guanghechen.types.ISubscribers
local Subscribers = {}

---@type guanghechen.types.IUnsubscribable
local noop_unsubscribable = {
  unsubscribe = util.misc.noop,
}

---@class guanghechen.subscriber.Subscribers.IOptions
---@field ARRANGE_THRESHOLD? number

---@class guanghechen.subscriber.Subscribers.ISubscriberItem
---@field subscriber guanghechen.types.ISubscriber
---@field unsubscribed boolean

---@param o table|nil
---@param options? guanghechen.subscriber.Subscribers.IOptions
---@return guanghechen.subscriber.Subscribers
function Subscribers:new(o, options)
  o = o or {}
  setmetatable(o, self)

  ---@type number
  self.ARRANGE_THRESHOLD = (options and options.ARRANGE_THRESHOLD) and options.ARRANGE_THRESHOLD or 16

  ---@type boolean
  self._disposed = false

  ---@type guanghechen.subscriber.Subscribers.ISubscriberItem[]
  self._items = {}

  ---@type number
  self._subscribingCount = 0

  return o
end

---@return number
function Subscribers:getSize()
  return self._subscribingCount
end

---@return boolean
function Subscribers:isDisposed()
  return self._disposed
end

---@return nil
function Subscribers:dispose()
  if self._disposed then
    return
  end

  self._disposed = true

  local batcher = SafeBatchHandler:new()
  local items = self._items

  local i = 1
  while i <= #items do
    local item = items[i]
    if item.unsubscribed then
      goto continue
    end

    item.unsubscribed = true
    if item.subscriber:isDisposed() then
      goto continue
    end

    batcher:run(function()
      item.subscriber:dispose()
    end)

    ::continue::
    i = i + 1
  end

  self._items = {}
  self._subscribingCount = 0
  batcher:summary("[Subscribers:dispose] Encountered errors while disposing.")
  batcher:cleanup()
end

---@param value any
---@param prev_value any
---@return nil
function Subscribers:notify(value, prev_value)
  if self._disposed then
    return
  end

  local batcher = SafeBatchHandler:new()
  local items = self._items

  local i = 1
  local L = #items
  while i <= L do
    local item = items[i]
    if not item.unsubscribed and not item.subscriber:isDisposed() then
      batcher:run(function()
        item.subscriber:next(value, prev_value)
      end)
    end
    i = i + 1
  end

  batcher:summary("[Subscribers:notify] Encountered errors while notifying subscribers.")
  batcher:cleanup()
end

---@param subscriber guanghechen.types.ISubscriber
---@return guanghechen.types.IUnsubscribable
function Subscribers:subscribe(subscriber)
  if subscriber:isDisposed() then
    return noop_unsubscribable
  end

  if self._disposed then
    subscriber:dispose()
    return noop_unsubscribable
  end

  ---@type guanghechen.subscriber.Subscribers.ISubscriberItem
  local item = { subscriber = subscriber, unsubscribed = false }

  table.insert(self._items, item)
  self._subscribingCount = self._subscribingCount + 1

  local cur = self

  ---@type guanghechen.types.IUnsubscribable
  local unsubscribe = {
    unsubscribe = function()
      if item.unsubscribed then
        return
      end

      item.unsubscribed = true
      cur._subscribingCount = cur._subscribingCount - 1
      cur:_arrange()
    end,
  }
  return unsubscribe
end

---@return nil
function Subscribers:_arrange()
  local items = self._items
  if #items >= self.ARRANGE_THRESHOLD and self._subscribingCount * 2 <= #items then
    ---@type guanghechen.subscriber.Subscribers.ISubscriberItem[]
    local next_items = {}

    local i = 1
    while i <= #items do
      local item = items[i]
      if not item.unsubscribed and not item.subscriber:isDisposed() then
        table.insert(next_items, item)
      end
      i = i + 1
    end

    self._items = next_items
    self._subscribingCount = #next_items
  end
end

return Subscribers
