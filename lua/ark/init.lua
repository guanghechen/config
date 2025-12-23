---@class ark.c.__mods
local c__mods = {
  BatchDisposable = "ark.c.batch_disposable",
  BatchHandler = "ark.c.batch_handler",
  CircularQueue = "ark.c.circular_queue",
  CircularStack = "ark.c.circular_stack",
  Dirtier = "ark.c.dirtier",
  Disposable = "ark.c.disposable",
  Frecency = "ark.c.frecency",
  History = "ark.c.history",
  InputHistory = "ark.c.input_history",
  Observable = "ark.c.observable",
  Proc = "ark.c.proc",
  Scheduler = "ark.c.scheduler",
  Subscriber = "ark.c.subscriber",
  Subscribers = "ark.c.subscribers",
  Ticker = "ark.c.ticker",
}

---@class ark.c
---@field public __mods                 ark.c.__mods
---@field public BatchDisposable        ark.c.BatchDisposable
---@field public BatchHandler           ark.c.BatchHandler
---@field public CircularQueue          ark.c.CircularQueue
---@field public CircularStack          ark.c.CircularStack
---@field public Dirtier                ark.c.Dirtier
---@field public Disposable             ark.c.Disposable
---@field public Frecency               ark.c.Frecency
---@field public History                ark.c.History
---@field public InputHistory           ark.c.InputHistory
---@field public Observable             ark.c.Observable
---@field public Proc                   ark.c.Proc
---@field public Scheduler              ark.c.Scheduler
---@field public Subscriber             ark.c.Subscriber
---@field public Subscribers            ark.c.Subscribers
---@field public Ticker                 ark.c.Ticker
local c = setmetatable({ __mods = c__mods }, {
  __index = function(t, k)
    local m = c__mods[k] ---@type string|nil
    if m == nil then
      return rawget(t, k)
    end
    return require(m)
  end,
})

----------------------------------------------------------------------------------------------------

---@class ark.__mods
local __mods = {
  anim = "ark.anim",
  box = "ark.box",
  color = "ark.external.color",
  debug = "ark.debug",
  easing = "ark.external.easing",
  env = "ark.env",
  fileicon = "ark.fileicon",
  filetype = "ark.filetype",
  fn = "ark.fn",
  fs = "ark.fs",
  hot = "ark.hot",
  icon = "ark.icon",
  nvim = "ark.nvim",
  reporter = "ark.reporter",
  stdout = "ark.stdout",
  string = "ark.string",
  table = "ark.table",
  time = "ark.time",
  timer = "ark.timer",
  tmux = "ark.tmux",
}

---@class ark
---@field public __mods                 ark.__mods
---@field public anim                   ark.anim
---@field public box                    ark.box
---@field public c                      ark.c
---@field public color                  ark.external.color
---@field public debug                  ark.debug
---@field public easing                 ark.external.easing
---@field public env                    ark.env
---@field public fileicon               ark.fileicon
---@field public filetype               ark.filetype
---@field public fn                     ark.fn
---@field public fs                     ark.fs
---@field public hot                    ark.hot
---@field public icon                   ark.icon
---@field public nvim                   ark.nvim
---@field public reporter               ark.reporter
---@field public stdout                 ark.stdout
---@field public string                 ark.string
---@field public table                  ark.table
---@field public time                   ark.time
---@field public timer                  ark.timer
---@field public tmux                   ark.tmux
local M = setmetatable({
  __mods = __mods,
  c = c,
}, {
  __index = function(t, k)
    local m = __mods[k] ---@type string|nil
    if m == nil then
      return rawget(t, k)
    end
    return require(m)
  end,
})

return M
