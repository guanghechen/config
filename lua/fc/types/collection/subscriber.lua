---@class fc.types.collection.ISubscriber : fc.types.collection.IDisposable
---@field public next                   fun(self: fc.types.collection.ISubscriber, value: fc.types.T, value_prev: fc.types.T| nil): nil

---@class fc.types.collection.IUnsubscribable
---@field public unsubscribe            fun(self: fc.types.collection.IUnsubscribable):nil

---@class fc.types.collection.ISubscribable
---@field public subscribe              fun(self: fc.types.collection.ISubscribable, subscriber: fc.types.collection.ISubscriber): fc.types.collection.IUnsubscribable

---@class fc.types.collection.ISubscribers : fc.types.collection.ISubscribable, fc.types.collection.IDisposable
---@field public count                  fun(self: fc.types.collection.ISubscribers): nil
---@field public notify                 fun(self: fc.types.collection.ISubscribers, value: fc.types.T, value_prev: fc.types.T | nil): nil
