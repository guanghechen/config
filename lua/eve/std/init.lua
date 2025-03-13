---@class eve.std.mods
local mods = {
  box = true,
  colors = true,
  debug = true,
  env = true,
  json = true,
  md5 = true,
  tmux = true,
}

---@class eve.std
---@field public box                    eve.std.box
---@field public colors                 eve.std.color
---@field public debug                  eve.std.debug
---@field public env                    eve.std.env
---@field public json                   eve.std.json
---@field public md5                    eve.std.md5
---@field public tmux                   eve.std.tmux
local M = setmetatable({}, {
  __index = function(t, k)
    if mods[k] then
      ---@diagnostic disable-next-line: no-unknown
      t[k] = require("eve.std." .. k)
    end
    return rawget(t, k)
  end,
})

return M
