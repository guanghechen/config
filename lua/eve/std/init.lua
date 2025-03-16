---@class eve.std.__mods
local __mods = {
  color = "eve.std.lib.color",
  md5 = "eve.std.lib.md5",

  fn = "eve.std.fn",
  
  BatchHandler = "eve.std.collection.batch_handler",
  Disposable = "eve.std.collection.disposable",
  Subscriber = "eve.std.collection.subscriber",
  Subscribers = "eve.std.collection.subscribers",
}

---@class eve.std
---@field public __mods                 eve.std.__mods
---
---@field public color                  eve.std.lib.color
---@field public md5                    eve.std.lib.md5
---
---@field public fn                     eve.std.fn
---
---@field public BatchHandler           eve.std.collection.BatchHandler
---@field public Disposable             eve.std.collection.Disposable
---@field public Subscriber             eve.std.collection.Subscriber
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
