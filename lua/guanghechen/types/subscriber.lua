---@class guanghechen.types.ISubscriber : guanghechen.types.IDisposable
---@field public  next fun(self: guanghechen.types.ISubscriber, value: guanghechen.types.T, prev_value: guanghechen.types.T| nil): nil

---@class guanghechen.types.IUnsubscribable
---@field public  unsubscribe fun(self: guanghechen.types.IUnsubscribable):nil

---@class guanghechen.types.ISubscribable
---@field public  subscirbe fun(self: guanghechen.types.ISubscribable, subscriber: guanghechen.types.ISubscriber): guanghechen.types.IUnsubscribable

---@class guanghechen.types.ISubscribers : guanghechen.types.ISubscribable, guanghechen.types.IDisposable
---@field public  getSize fun(self: guanghechen.types.ISubscribers):nil
---@field public  notify fun(self: guanghechen.types.ISubscribers, value: guanghechen.types.T, prev_value: guanghechen.types.T | nil): nil
