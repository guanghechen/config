---@class ark.c.__mods
local c__mods = {
  BatchDisposable = "ark.c.batch_disposable",
  BatchHandler = "ark.c.batch_handler",
  CircularQueue = "ark.c.circular_queue",
  CircularStack = "ark.c.circular_stack",
  Disposable = "ark.c.disposable",
  Frecency = "ark.c.frecency",
  History = "ark.c.history",
  InputHistory = "ark.c.input_history",
  Subscriber = "ark.c.subscriber",
  Subscribers = "ark.c.subscribers",
}

---@class ark.c
---@field public __mods                 ark.c.__mods
---@field public BatchDisposable        ark.c.BatchDisposable
---@field public BatchHandler           ark.c.BatchHandler
---@field public CircularQueue          ark.c.CircularQueue
---@field public CircularStack          ark.c.CircularStack
---@field public Disposable             ark.c.Disposable
---@field public Frecency               ark.c.Frecency
---@field public History                ark.c.History
---@field public InputHistory           ark.c.InputHistory
---@field public Subscriber             ark.c.Subscriber
---@field public Subscribers            ark.c.Subscribers
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
  color = "ark.external.color",
  easing = "ark.external.easing",
  fn = "ark.fn",
  reporter = "ark.reporter",
  stdout = "ark.stdout",
  time = "ark.time",
  tmux = "ark.tmux",
}

---@class ark
---@field public __mods                 ark.__mods
---@field public anim                   ark.anim
---@field public c                      ark.c
---@field public color                  ark.external.color
---@field public easing                 ark.external.easing
---@field public fn                     ark.fn
---@field public reporter               ark.reporter
---@field public stdout                 ark.stdout
---@field public time                   ark.time
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
