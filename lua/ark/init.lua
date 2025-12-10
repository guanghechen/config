---@class ark.c.__mods
local c__mods = {
  BatchDisposable = "ark.c.batch_disposable",
  BatchHandler = "ark.c.batch_handler",
  CircularQueue = "ark.c.circular_queue",
  CircularStack = "ark.c.circular_stack",
  Disposable = "ark.c.disposable",
  Subscriber = "ark.c.subscriber",
}

---@class ark.c
---@field public __mods                 ark.c.__mods
---@field public BatchDisposable        ark.c.BatchDisposable
---@field public BatchHandler           ark.c.BatchHandler
---@field public CircularQueue          ark.c.CircularQueue
---@field public CircularStack          ark.c.CircularStack
---@field public Disposable             ark.c.Disposable
---@field public Subscriber             ark.c.Subscriber
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
  color = "ark.external.color",
  easing = "ark.external.easing",
  fn = "ark.fn",
  reporter = "ark.reporter",
}

---@class ark
---@field public __mods                 ark.__mods
---@field public c                      ark.c
---@field public color                  ark.external.color
---@field public easing                 ark.external.easing
---@field public fn                     ark.fn
---@field public reporter               ark.reporter
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
