local __module_name__ = "ark.c.subscribers" ---@type string

---@class ark.c.ISubscribable
---@field public subscribe              fun(self: ark.c.ISubscribable, subscriber: ark.c.ISubscriber, ignoreInitial?: boolean): ark.c.IUnsubscribable

---@class ark.c.ISubscribers : ark.c.ISubscribable, ark.c.IDisposable
---@field public count                  fun(self: ark.c.ISubscribers): nil
---@field public notify                 fun(self: ark.c.ISubscribers, value: ark.t.T, value_prev: ark.t.T | nil): nil

---@class ark.c.subscribers.IProps
---@field public ARRANGE_THRESHOLD      ?number

---@class ark.c.subscribers.ISubscriberItem
---@field public subscriber             ark.c.ISubscriber
---@field public unsubscribed           boolean

---@type ark.c.IUnsubscribable
local noop_unsubscribable = { unsubscribe = ark.fn.noop }

---@class ark.c.Subscribers : ark.c.ISubscribers
---@field protected ARRANGE_THRESHOLD   number
---@field protected _disposed           boolean
---@field protected _items              ark.c.subscribers.ISubscriberItem[]
---@field protected _subscribing_count  integer
local M = {}
M.__index = M

---@param props                         ?ark.c.subscribers.IProps
---@return ark.c.Subscribers
function M.new(props)
  local self = setmetatable({}, M)

  ---@type integer
  self.ARRANGE_THRESHOLD = (props and props.ARRANGE_THRESHOLD) and props.ARRANGE_THRESHOLD or 16

  ---@type boolean
  self._disposed = false

  ---@type ark.c.subscribers.ISubscriberItem[]
  self._items = {}

  ---@type integer
  self._subscribing_count = 0

  return self
end

---@return number
function M:count()
  return self._subscribing_count
end

---@return boolean
function M:isdisposed()
  return self._disposed
end

---@return nil
function M:dispose()
  if self._disposed then
    return
  end
  self._disposed = true

  local handler = ark.c.BatchHandler.new()
  local items = self._items

  local i = 1
  while i <= #items do
    local item = items[i]
    if item.unsubscribed then
      goto continue
    end

    item.unsubscribed = true
    if item.subscriber:isdisposed() then
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

---@param value                         any
---@param value_prev                    any
---@return nil
function M:notify(value, value_prev)
  if self._disposed then
    return
  end

  local handler = ark.c.BatchHandler.new()
  local items = self._items

  local i = 1
  local L = #items
  while i <= L do
    local item = items[i]
    if not item.unsubscribed and not item.subscriber:isdisposed() then
      handler:run(function()
        item.subscriber:next(value, value_prev)
      end)
    end
    i = i + 1
  end

  handler:summary("[Subscribers:notify] Encountered errors while notifying subscribers.")
  handler:cleanup()
end

---@param subscriber                    ark.c.ISubscriber
---@return ark.c.IUnsubscribable
function M:subscribe(subscriber)
  if subscriber:isdisposed() then
    return noop_unsubscribable
  end

  if self._disposed then
    subscriber:dispose()
    return noop_unsubscribable
  end

  ---@type ark.c.subscribers.ISubscriberItem
  local item = { subscriber = subscriber, unsubscribed = false }

  table.insert(self._items, item)
  self._subscribing_count = self._subscribing_count + 1

  ---@type ark.c.IUnsubscribable
  local unsubscribe = {
    unsubscribe = function()
      if item.unsubscribed then
        return
      end

      item.unsubscribed = true
      self._subscribing_count = self._subscribing_count - 1
      self:__arrange__()
    end,
  }
  return unsubscribe
end

----------------------------------------------------------------------------------------------------

---@protected
---@return nil
function M:__arrange__()
  local items = self._items
  if #items >= self.ARRANGE_THRESHOLD and self._subscribing_count * 2 <= #items then
    ---@type ark.c.subscribers.ISubscriberItem[]
    local next_items = {}

    local i = 1
    while i <= #items do
      local item = items[i]
      if not item.unsubscribed and not item.subscriber:isdisposed() then
        table.insert(next_items, item)
      end
      i = i + 1
    end

    self._items = next_items
    self._subscribing_count = #next_items
  end
end

---@protected
---@return nil
function M:__health__()
  if self._disposed then
    local message = string.format("[%s] already been disposed.", __module_name__) ---@type string
    error(message)
  end
end

return M
