---@class eve.std.__mods
local __mods = {
  box = "eve.std.box",
  color = "eve.std.color",
  debug = "eve.std.debug",
  env = "eve.std.env",
  fn = "eve.std.fn",
  fs = "eve.std.fs",
  im = "eve.std.im",
  is = "eve.std.is",
  json = "eve.std.json",
  lsp = "eve.std.lsp",
  nvim = "eve.std.nvim",
  oxi = "eve.std.oxi",
  path = "eve.std.path",
  reporter = "eve.std.reporter",
  shell = "eve.std.shell",
  string = "eve.std.string",
  table = "eve.std.table",
  tmux = "eve.std.tmux",
}

---@class eve.std
---@field public __mods                 eve.std.__mods
---
---@field public box                    eve.std.box
---@field public color                  eve.std.color
---@field public debug                  eve.std.debug
---@field public env                    eve.std.env
---@field public fn                     eve.std.fn
---@field public fs                     eve.std.fs
---@field public is                     eve.std.is
---@field public im                     eve.std.im
---@field public json                   eve.std.json
---@field public nvim                   eve.std.nvim
---@field public oxi                    eve.std.oxi
---@field public path                   eve.std.path
---@field public reporter               eve.std.reporter
---@field public shell                  eve.std.shell
---@field public string                 eve.std.string
---@field public table                  eve.std.table
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
