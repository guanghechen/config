---@class std.__mods
local __mods = {
  color = "std.lib.color",
  easing = "std.lib.easing",

  byte = "std.byte",
  debug = "std.debug",
  env = "std.env",
  fileicon = "std.fileicon",
  fn = "std.fn",
  fs = "std.fs",
  is = "std.is",
  job = "std.job",
  json = "std.json",
  path = "std.path",
  reporter = "std.reporter",
  string = "std.string",
  table = "std.table",
  timer = "std.timer",
  tmux = "std.tmux",

  BatchDisposable = "std.collection.batch_disposable",
  BatchHandler = "std.collection.batch_handler",
  CircularQueue = "std.collection.circular_queue",
  CircularStack = "std.collection.circular_stack",
  Dirtier = "std.collection.dirtier",
  Disposable = "std.collection.disposable",
  Filetree = "std.collection.filetree",
  Frecency = "std.collection.frecency",
  History = "std.collection.history",
  InputHistory = "std.collection.input_history",
  Observable = "std.collection.observable",
  Promise = "std.collection.promise",
  Scheduler = "std.collection.scheduler",
  Spawn = "std.collection.spawn",
  Subscriber = "std.collection.subscriber",
  Subscribers = "std.collection.subscribers",
  Theme = "std.collection.theme",
  Ticker = "std.collection.ticker",
  Tree = "std.collection.tree",
}

---@class std
---@field public __mods                 std.__mods
---
---@field public color                  std.lib.color
---@field public easing                 std.lib.easing
---
---@field public byte                   std.byte
---@field public debug                  std.debug
---@field public env                    std.env
---@field public fileicon               std.fileicon
---@field public fn                     std.fn
---@field public fs                     std.fs
---@field public is                     std.is
---@field public job                    std.job
---@field public json                   std.json
---@field public path                   std.path
---@field public reporter               std.reporter
---@field public string                 std.string
---@field public table                  std.table
---@field public timer                  std.timer
---@field public tmux                   std.tmux
---
---@field public BatchDisposable        std.collection.BatchDisposable
---@field public BatchHandler           std.collection.BatchHandler
---@field public CircularQueue          std.collection.CircularQueue
---@field public CircularStack          std.collection.CircularStack
---@field public Dirtier                std.collection.Dirtier
---@field public Disposable             std.collection.Disposable
---@field public Filetree               std.collection.Filetree
---@field public Frecency               std.collection.Frecency
---@field public History                std.collection.History
---@field public InputHistory           std.collection.InputHistory
---@field public Observable             std.collection.Observable
---@field public Promise                std.collection.Promise
---@field public Scheduler              std.collection.Scheduler
---@field public Spawn                  std.collection.Spawn
---@field public Subscriber             std.collection.Subscriber
---@field public Subscribers            std.collection.Subscribers
---@field public Theme                  std.collection.Theme
---@field public Ticker                 std.collection.Ticker
---@field public Tree                   std.collection.Tree
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
