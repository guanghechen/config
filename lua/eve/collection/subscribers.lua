local BatchHandler = require("eve.collection.batch_handler")

---@class eve.collection.Subscribers : t.eve.collection.ISubscribers
---@field private ARRANGE_THRESHOLD     number
---@field private _disposed             boolean
---@field private _items                eve.collection.Subscribers.ISubscriberItem[]
---@field private _subscribing_count    integer
local M = {}
M.__index = M

---@type t.eve.collection.IUnsubscribable
local noop_unsubscribable = {
  unsubscribe = function(...) end,
}

---@class eve.collection.Subscribers.IProps
---@field public ARRANGE_THRESHOLD      ?number

---@class eve.collection.Subscribers.ISubscriberItem
---@field subscriber                    t.eve.collection.ISubscriber
---@field unsubscribed                  boolean

---@param props                         ?eve.collection.Subscribers.IProps
---@return eve.collection.Subscribers
function M.new(props)
  local self = setmetatable({}, M)

  ---@type number
  self.ARRANGE_THRESHOLD = (props and props.ARRANGE_THRESHOLD) and props.ARRANGE_THRESHOLD or 16

  ---@type boolean
  self._disposed = false

  ---@type eve.collection.Subscribers.ISubscriberItem[]
  self._items = {}

  ---@type number
  self._subscribing_count = 0

  return self
end

---@return number
function M:count()
  return self._subscribing_count
end

---@return boolean
function M:is_disposed()
  return self._disposed
end

---@return nil
function M:dispose()
  if self._disposed then
    return
  end

  self._disposed = true

  local handler = BatchHandler.new()
  local items = self._items

  local i = 1
  while i <= #items do
    local item = items[i]
    if item.unsubscribed then
      goto continue
    end

    item.unsubscribed = true
    if item.subscriber:is_disposed() then
      goto continue
    end

    handler:run(function()
      item.subscriber:dispose()
    end)

    ::continue::
    i = i + 1
  end

  self._items = {}
  self._subscribing_count = 0
  handler:summary("[Subscribers:dispose] Encountered errors while disposing.")
  handler:cleanup()
end

---@param value any
---@param value_prev any
---@return nil
function M:notify(value, value_prev)
  if self._disposed then
    return
  end

  local handler = BatchHandler:new()
  local items = self._items

  local i = 1
  local L = #items
  while i <= L do
    local item = items[i]
    if not item.unsubscribed and not item.subscriber:is_disposed() then
      handler:run(function()
        item.subscriber:next(value, value_prev)
      end)
    end
    i = i + 1
  end

  handler:summary("[Subscribers:notify] Encountered errors while notifying subscribers.")
  handler:cleanup()
end

---@param subscriber                    t.eve.collection.ISubscriber
---@return t.eve.collection.IUnsubscribable
function M:subscribe(subscriber)
  if subscriber:is_disposed() then
    return noop_unsubscribable
  end

  if self._disposed then
    subscriber:dispose()
    return noop_unsubscribable
  end

  ---@type eve.collection.Subscribers.ISubscriberItem
  local item = { subscriber = subscriber, unsubscribed = false }

  table.insert(self._items, item)
  self._subscribing_count = self._subscribing_count + 1

  ---@type t.eve.collection.IUnsubscribable
  local unsubscribe = {
    unsubscribe = function()
      if item.unsubscribed then
        return
      end

      item.unsubscribed = true
      self._subscribing_count = self._subscribing_count - 1
      self:_arrange()
    end,
  }
  return unsubscribe
end

---@return nil
function M:_arrange()
  local items = self._items
  if #items >= self.ARRANGE_THRESHOLD and self._subscribing_count * 2 <= #items then
    ---@type eve.collection.Subscribers.ISubscriberItem[]
    local next_items = {}

    local i = 1
    while i <= #items do
      local item = items[i]
      if not item.unsubscribed and not item.subscriber:is_disposed() then
        table.insert(next_items, item)
      end
      i = i + 1
    end

    self._items = next_items
    self._subscribing_count = #next_items
  end
end

return M
