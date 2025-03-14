---@class eve.std.__mods
local __mods = {
  box = "eve.std.box",
  fs = "eve.std.fs",
  im = "eve.std.im",
  lsp = "eve.std.lsp",
  nvim = "eve.std.nvim",
  shell = "eve.std.shell",
  tmux = "eve.std.tmux",
}

---@class eve.std
---@field public __mods                 eve.std.__mods
---
---@field public box                    eve.std.box
---@field public fs                     eve.std.fs
---@field public im                     eve.std.im
---@field public nvim                   eve.std.nvim
---@field public shell                  eve.std.shell
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
