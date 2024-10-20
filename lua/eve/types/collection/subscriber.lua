---@class t.eve.collection.ISubscriber : t.eve.collection.IDisposable
---@field public next                   fun(self: t.eve.collection.ISubscriber, value: t.eve.T, value_prev: t.eve.T| nil): nil

---@class t.eve.collection.IUnsubscribable
---@field public unsubscribe            fun(self: t.eve.collection.IUnsubscribable):nil

---@class t.eve.collection.ISubscribable
---@field public subscribe              fun(self: t.eve.collection.ISubscribable, subscriber: t.eve.collection.ISubscriber, ignoreInitial?: boolean): t.eve.collection.IUnsubscribable

---@class t.eve.collection.ISubscribers : t.eve.collection.ISubscribable, t.eve.collection.IDisposable
---@field public count                  fun(self: t.eve.collection.ISubscribers): nil
---@field public notify                 fun(self: t.eve.collection.ISubscribers, value: t.eve.T, value_prev: t.eve.T | nil): nil
