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

---@class ark.dict.__mods
local dict__mods = {
  en = "ark.dict.en",
}

---@class ark.dict
---@field public __mods                 ark.dict.__mods
---@field public en                     { [1]: string, [2]: string }[]
local dict = setmetatable({ __mods = dict__mods }, {
  __index = function(t, k)
    local m = dict__mods[k] ---@type string|nil
    if m == nil then
      return rawget(t, k)
    end
    return require(m)
  end,
})

----------------------------------------------------------------------------------------------------

---@class ark.lang.__mods
local lang__mods = {
  python = "ark.lang.python",
  tailwind = "ark.lang.tailwind",
}

---@class ark.lang
---@field public __mods                 ark.lang.__mods
---@field public python                 ark.lang.python
---@field public tailwind               ark.lang.tailwind
local lang = setmetatable({ __mods = lang__mods }, {
  __index = function(t, k)
    local m = lang__mods[k] ---@type string|nil
    if m == nil then
      return rawget(t, k)
    end
    return require(m)
  end,
})

----------------------------------------------------------------------------------------------------

---@class ark.__mods
local __mods = {
  color = "ark.external.color",
  easing = "ark.external.easing",

  anim = "ark.anim",
  box = "ark.box",
  debug = "ark.debug",
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
---@field public dict                   ark.dict
---@field public easing                 ark.external.easing
---@field public env                    ark.env
---@field public fileicon               ark.fileicon
---@field public filetype               ark.filetype
---@field public fn                     ark.fn
---@field public fs                     ark.fs
---@field public hot                    ark.hot
---@field public icon                   ark.icon
---@field public lang                   ark.lang
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
  dict = dict,
  lang = lang,
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
