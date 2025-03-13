---@class eve.collection.__mods
local __mods = {
  BatchDisposable = "eve.collection.batch_disposable",
  BatchHandler = "eve.collection.batch_handler",
  CircularQueue = "eve.collection.circular_queue",
  CircularStack = "eve.collection.circular_stack",
  Dirtier = "eve.collection.dirtier",
  Disposable = "eve.collection.disposable",
  Frecency = "eve.collection.frecency",
  History = "eve.collection.history",
  HistoryAdvance = "eve.collection.history_advance",
  Observable = "eve.collection.observable",
  Promise = "eve.collection.promise",
  Scheduler = "eve.collection.scheduler",
  Spawn = "eve.collection.spawn",
  Subscriber = "eve.collection.subscriber",
  Subscribers = "eve.collection.subscribers",
  Theme = "eve.collection.theme",
  Ticker = "eve.collection.ticker",
}

---@class eve.collection
---@field public __mods                 eve.collection.__mods
---
---@field public BatchDisposable        eve.collection.BatchDisposable
---@field public BatchHandler           eve.collection.BatchHandler
---@field public CircularQueue          eve.collection.CircularQueue
---@field public CircularStack          eve.collection.CircularStack
---@field public Dirtier                eve.collection.Dirtier
---@field public Disposable             eve.collection.Disposable
---@field public Frecency               eve.collection.Frecency
---@field public History                eve.collection.History
---@field public HistoryAdvance         eve.collection.AdvanceHistory
---@field public Observable             eve.collection.Observable
---@field public Promise                eve.collection.Promise
---@field public Scheduler              eve.collection.Scheduler
---@field public Spawn                  eve.collection.Spawn
---@field public Subscriber             eve.collection.Subscriber
---@field public Subscribers            eve.collection.Subscribers
---@field public Theme                  eve.collection.Theme
---@field public Ticker                 eve.collection.Ticker
local M = setmetatable({ __mods = __mods }, {
  __index = function(t, k)
    local m = __mods[k] ---@type string|nil
    if m == nil then
      return rawget(t, k)
    end
    return require(m)
  end,
})

return M
