---@class eve.std.__mods
local __mods = {
  array = "eve.std.array",
  box = "eve.std.box",
  color = "eve.std.color",
  debug = "eve.std.debug",
  env = "eve.std.env",
  fs = "eve.std.fs",
  json = "eve.std.json",
  md5 = "eve.std.md5",
  path = "eve.std.path",
  reporter = "eve.std.reporter",
  string = "eve.std.string",
  tmux = "eve.std.tmux",
  win = "eve.std.win",
}

---@class eve.std
---@field public __mods                 eve.std.__mods
---
---@field public array                  eve.std.array
---@field public box                    eve.std.box
---@field public color                  eve.std.color
---@field public debug                  eve.std.debug
---@field public env                    eve.std.env
---@field public fs                     eve.std.fs
---@field public json                   eve.std.json
---@field public md5                    eve.std.md5
---@field public path                   eve.std.path
---@field public reporter               eve.std.reporter
---@field public string                 eve.std.string
---@field public tmux                   eve.std.tmux
---@field public win                    eve.std.win
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
