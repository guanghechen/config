---@class t.eve.collection.IScheduler
---@field public name                   string
---@field public cancel                 fun(self: t.eve.collection.IScheduler): nil
---@field public mark_dirty             fun(self: t.eve.collection.IScheduler): nil
---@field public schedule               fun(self: t.eve.collection.IScheduler): nil
---@field public snapshot               fun(self: t.eve.collection.IScheduler): unknown|nil

---@alias t.eve.collection.scheduler.ITask
---| fun(callback: t.eve.collection.promise.IOnFinally): nil
