local SafeBatchHandler = require("guanghechen.disposable.SafeBatchHandler")
local util_misc = require("guanghechen.util.misc")

---@class guanghechen.subscriber.Subscribers : guanghechen.types.ISubscribers
---@field private ARRANGE_THRESHOLD  number
local Subscribers = {}
Subscribers.__index = Subscribers

---@class guanghechen.subscriber.Subscribers.IOptions
---@field ARRANGE_THRESHOLD? number

---@class guanghechen.subscriber.Subscribers.ISubscriberItem
---@field subscriber guanghechen.types.ISubscriber
---@field unsubscribed boolean

---@param options? guanghechen.subscriber.Subscribers.IOptions
---@return guanghechen.subscriber.Subscribers
function Subscribers.new(options)
  local self = setmetatable({}, Subscribers)

  ---@type number
  self.ARRANGE_THRESHOLD = (options and options.ARRANGE_THRESHOLD) and options.ARRANGE_THRESHOLD or 16

  ---@type boolean
  self._disposed = false

  ---@type guanghechen.subscriber.Subscribers.ISubscriberItem[]
  self._items = {}

  ---@type number
  self._subscribingCount = 0

  return self
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
---@param value_prev any
---@return nil
function Subscribers:notify(value, value_prev)
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
        item.subscriber:next(value, value_prev)
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
    return util_misc.noop_unsubscribable
  end

  if self._disposed then
    subscriber:dispose()
    return util_misc.noop_unsubscribable
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
