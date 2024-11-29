---@class eve.t.collection.ISubscriber : eve.t.collection.IDisposable
---@field public next                   fun(self: eve.t.collection.ISubscriber, value: eve.t.T, value_prev: eve.t.T| nil): nil

---@class eve.t.collection.IUnsubscribable
---@field public unsubscribe            fun(self: eve.t.collection.IUnsubscribable):nil

---@class eve.t.collection.ISubscribable
---@field public subscribe              fun(self: eve.t.collection.ISubscribable, subscriber: eve.t.collection.ISubscriber, ignoreInitial?: boolean): eve.t.collection.IUnsubscribable

---@class eve.t.collection.ISubscribers : eve.t.collection.ISubscribable, eve.t.collection.IDisposable
---@field public count                  fun(self: eve.t.collection.ISubscribers): nil
---@field public notify                 fun(self: eve.t.collection.ISubscribers, value: eve.t.T, value_prev: eve.t.T | nil): nil
