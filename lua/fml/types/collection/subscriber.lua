---@class fml.types.collection.ISubscriber : fml.types.collection.IDisposable
---@field public next                   fun(self: fml.types.collection.ISubscriber, value: fml.types.T, value_prev: fml.types.T| nil): nil

---@class fml.types.collection.IUnsubscribable
---@field public unsubscribe            fun(self: fml.types.collection.IUnsubscribable):nil

---@class fml.types.collection.ISubscribable
---@field public subscribe              fun(self: fml.types.collection.ISubscribable, subscriber: fml.types.collection.ISubscriber): fml.types.collection.IUnsubscribable

---@class fml.types.collection.ISubscribers : fml.types.collection.ISubscribable, fml.types.collection.IDisposable
---@field public count                  fun(self: fml.types.collection.ISubscribers): nil
---@field public notify                 fun(self: fml.types.collection.ISubscribers, value: fml.types.T, value_prev: fml.types.T | nil): nil
