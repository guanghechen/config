---@class eve.std.__mods
local __mods = {
  box = "eve.std.box",
  color = "eve.std.color",
  debug = "eve.std.debug",
  env = "eve.std.env",
  json = "eve.std.json",
  md5 = "eve.std.md5",
  path = "eve.std.path",
  tmux = "eve.std.tmux",
}

---@class eve.std
---@field public __mods                 eve.std.__mods
---@field public box                    eve.std.box
---@field public color                  eve.std.color
---@field public debug                  eve.std.debug
---@field public env                    eve.std.env
---@field public json                   eve.std.json
---@field public md5                    eve.std.md5
---@field public tmux                   eve.std.tmux
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
