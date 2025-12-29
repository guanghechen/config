---@class stl.c.__mods
local c__mods = {
  BatchDisposable = "stl.c.batch_disposable",
  BatchHandler = "stl.c.batch_handler",
  CircularQueue = "stl.c.circular_queue",
  CircularStack = "stl.c.circular_stack",
  Dirtier = "stl.c.dirtier",
  Disposable = "stl.c.disposable",
  Filetree = "stl.c.filetree",
  Frecency = "stl.c.frecency",
  History = "stl.c.history",
  InputHistory = "stl.c.input_history",
  Observable = "stl.c.observable",
  Proc = "stl.c.proc",
  Scheduler = "stl.c.scheduler",
  Subscriber = "stl.c.subscriber",
  Subscribers = "stl.c.subscribers",
  Theme = "stl.c.theme",
  Ticker = "stl.c.ticker",
  Tree = "stl.c.tree",
  TreeRetriever = "stl.c.tree_retriever",
}

---@class stl.c
---@field public __mods                 stl.c.__mods
---@field public BatchDisposable        stl.c.BatchDisposable
---@field public BatchHandler           stl.c.BatchHandler
---@field public CircularQueue          stl.c.CircularQueue
---@field public CircularStack          stl.c.CircularStack
---@field public Dirtier                stl.c.Dirtier
---@field public Disposable             stl.c.Disposable
---@field public Filetree               stl.c.Filetree
---@field public Frecency               stl.c.Frecency
---@field public History                stl.c.History
---@field public InputHistory           stl.c.InputHistory
---@field public Observable             stl.c.Observable
---@field public Proc                   stl.c.Proc
---@field public Scheduler              stl.c.Scheduler
---@field public Subscriber             stl.c.Subscriber
---@field public Subscribers            stl.c.Subscribers
---@field public Theme                  stl.c.Theme
---@field public Ticker                 stl.c.Ticker
---@field public Tree                   stl.c.Tree
---@field public TreeRetriever          stl.c.TreeRetriever
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

---@class stl.dict.__mods
local dict__mods = {
  en = "stl.dict.en",
}

---@class stl.dict
---@field public __mods                 stl.dict.__mods
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

---@class stl.lang.__mods
local lang__mods = {
  python = "stl.lang.python",
  tailwind = "stl.lang.tailwind",
}

---@class stl.lang
---@field public __mods                 stl.lang.__mods
---@field public python                 stl.lang.python
---@field public tailwind               stl.lang.tailwind
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

---@class stl.__mods
local __mods = {
  color = "stl.external.color",
  easing = "stl.external.easing",

  debug = "stl.debug",
  env = "stl.env",
  fileicon = "stl.fileicon",
  filetype = "stl.filetype",
  fn = "stl.fn",
  fs = "stl.fs",
  hot = "stl.hot",
  icon = "stl.icon",
  json = "stl.json",
  reporter = "stl.reporter",
  stdout = "stl.stdout",
  string = "stl.string",
  table = "stl.table",
  timer = "stl.timer",
  tmux = "stl.tmux",
  winhint = "stl.winhint",
}

---@class stl
---@field public __mods                 stl.__mods
---@field public c                      stl.c
---@field public color                  stl.external.color
---@field public easing                 stl.external.easing
---
---@field public dict                   stl.dict
---@field public lang                   stl.lang
---
---@field public debug                  stl.debug
---@field public env                    stl.env
---@field public fileicon               stl.fileicon
---@field public filetype               stl.filetype
---@field public fn                     stl.fn
---@field public fs                     stl.fs
---@field public hot                    stl.hot
---@field public icon                   stl.icon
---@field public json                   stl.json
---@field public reporter               stl.reporter
---@field public stdout                 stl.stdout
---@field public string                 stl.string
---@field public table                  stl.table
---@field public timer                  stl.timer
---@field public tmux                   stl.tmux
---@field public winhint                stl.winhint
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
