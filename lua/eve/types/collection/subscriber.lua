---@class eve.types.collection.ISubscriber : eve.types.collection.IDisposable
---@field public next                   fun(self: eve.types.collection.ISubscriber, value: eve.types.T, value_prev: eve.types.T| nil): nil

---@class eve.types.collection.IUnsubscribable
---@field public unsubscribe            fun(self: eve.types.collection.IUnsubscribable):nil

---@class eve.types.collection.ISubscribable
---@field public subscribe              fun(self: eve.types.collection.ISubscribable, subscriber: eve.types.collection.ISubscriber): eve.types.collection.IUnsubscribable

---@class eve.types.collection.ISubscribers : eve.types.collection.ISubscribable, eve.types.collection.IDisposable
---@field public count                  fun(self: eve.types.collection.ISubscribers): nil
---@field public notify                 fun(self: eve.types.collection.ISubscribers, value: eve.types.T, value_prev: eve.types.T | nil): nil
