---@class guanghechen.types.ISubscriber : guanghechen.types.IDisposable
---@field next fun(self: guanghechen.types.ISubscriber, value: any, prev_value: any | nil): nil

---@class guanghechen.types.IUnsubscribable
---@field unsubscribe fun(self: guanghechen.types.IUnsubscribable):nil

---@class guanghechen.types.ISubscribable
---@field subscirbe fun(self: guanghechen.types.ISubscribable, subscriber: guanghechen.types.ISubscriber): guanghechen.types.IUnsubscribable

---@class guanghechen.types.ISubscribers : guanghechen.types.ISubscribable, guanghechen.types.IDisposable
---@field getSize fun(self: guanghechen.types.ISubscribers):nil
---@field notify fun(self: guanghechen.types.ISubscribers, value: any, prev_value: any | nil): nil
