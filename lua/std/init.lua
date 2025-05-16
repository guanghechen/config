---@class std.__mods
local __mods = {
  base64 = "std.lib.base64",
  color = "std.lib.color",
  easing = "std.lib.easing",

  debug = "std.debug",
  env = "std.env",
  fn = "std.fn",
  fs = "std.fs",
  is = "std.is",
  json = "std.json",
  path = "std.path",
  reporter = "std.reporter",
  string = "std.string",
  table = "std.table",
  timer = "std.timer",

  BatchDisposable = "std.collection.batch_disposable",
  BatchHandler = "std.collection.batch_handler",
  BufRetriever = "std.collection.buf_retriever",
  CircularQueue = "std.collection.circular_queue",
  CircularStack = "std.collection.circular_stack",
  Dirtier = "std.collection.dirtier",
  Disposable = "std.collection.disposable",
  Frecency = "std.collection.frecency",
  History = "std.collection.history",
  Observable = "std.collection.observable",
  Promise = "std.collection.promise",
  Scheduler = "std.collection.scheduler",
  Spawn = "std.collection.spawn",
  Subscriber = "std.collection.subscriber",
  Subscribers = "std.collection.subscribers",
  Theme = "std.collection.theme",
  Ticker = "std.collection.ticker",
}

---@class std
---@field public __mods                 std.__mods
---
---@field public base64                 std.lib.base64
---@field public color                  std.lib.color
---@field public easing                 std.lib.easing
---
---@field public debug                  std.debug
---@field public env                    std.env
---@field public fn                     std.fn
---@field public fs                     std.fs
---@field public is                     std.is
---@field public json                   std.json
---@field public path                   std.path
---@field public reporter               std.reporter
---@field public string                 std.string
---@field public table                  std.table
---@field public timer                  std.timer
---
---@field public BatchDisposable        std.collection.BatchDisposable
---@field public BatchHandler           std.collection.BatchHandler
---@field public BufRetriever           std.collection.BufRetriever
---@field public CircularQueue          std.collection.CircularQueue
---@field public CircularStack          std.collection.CircularStack
---@field public Dirtier                std.collection.Dirtier
---@field public Disposable             std.collection.Disposable
---@field public Frecency               std.collection.Frecency
---@field public History                std.collection.History
---@field public Observable             std.collection.Observable
---@field public Promise                std.collection.Promise
---@field public Scheduler              std.collection.Scheduler
---@field public Spawn                  std.collection.Spawn
---@field public Subscriber             std.collection.Subscriber
---@field public Subscribers            std.collection.Subscribers
---@field public Theme                  std.collection.Theme
---@field public Ticker                 std.collection.Ticker
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
