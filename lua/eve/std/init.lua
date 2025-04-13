---@class eve.std.__mods
local __mods = {
  base64 = "eve.std.lib.base64",
  color = "eve.std.lib.color",
  md5 = "eve.std.lib.md5",

  fn = "eve.std.fn",
  is = "eve.std.is",

  BatchDisposable = "eve.std.collection.batch_disposable",
  BatchHandler = "eve.std.collection.batch_handler",
  CircularQueue = "eve.std.collection.circular_queue",
  CircularStack = "eve.std.collection.circular_stack",
  Dirtier = "eve.std.collection.dirtier",
  Disposable = "eve.std.collection.disposable",
  Frecency = "eve.std.collection.frecency",
  History = "eve.std.collection.history",
  AdvanceHistory = "eve.std.collection.history_advance",
  Observable = "eve.std.collection.observable",
  Promise = "eve.std.collection.promise",
  Scheduler = "eve.std.collection.scheduler",
  Spawn = "eve.std.collection.spawn",
  Subscriber = "eve.std.collection.subscriber",
  Subscribers = "eve.std.collection.subscribers",
  Theme = "eve.std.collection.theme",
  Ticker = "eve.std.collection.ticker",
}

---@class eve.std
---@field public __mods                 eve.std.__mods
---
---@field public base64                 eve.std.lib.base64
---@field public color                  eve.std.lib.color
---@field public md5                    eve.std.lib.md5
---
---@field public fn                     eve.std.fn
---@field public is                     eve.std.is
---
---@field public BatchDisposable        eve.std.collection.BatchDisposable
---@field public BatchHandler           eve.std.collection.BatchHandler
---@field public CircularQueue          eve.std.collection.CircularQueue
---@field public CircularStack          eve.std.collection.CircularStack
---@field public Dirtier                eve.std.collection.Dirtier
---@field public Disposable             eve.std.collection.Disposable
---@field public Frecency               eve.std.collection.Frecency
---@field public History                eve.std.collection.History
---@field public AdvanceHistory         eve.std.collection.AdvanceHistory
---@field public Observable             eve.std.collection.Observable
---@field public Promise                eve.std.collection.Promise
---@field public Scheduler              eve.std.collection.Scheduler
---@field public Spawn                  eve.std.collection.Spawn
---@field public Subscriber             eve.std.collection.Subscriber
---@field public Subscribers            eve.std.collection.Subscribers
---@field public Theme                  eve.std.collection.Theme
---@field public Ticker                 eve.std.collection.Ticker
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
