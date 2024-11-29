---@class eve.t.collection.IScheduler
---@field public name                   string
---@field public cancel                 fun(self: eve.t.collection.IScheduler): nil
---@field public mark_dirty             fun(self: eve.t.collection.IScheduler): nil
---@field public schedule               fun(self: eve.t.collection.IScheduler): nil
---@field public snapshot               fun(self: eve.t.collection.IScheduler): unknown|nil

---@alias eve.t.collection.scheduler.ITask
---| fun(callback: eve.t.collection.promise.IOnFinally): nil
