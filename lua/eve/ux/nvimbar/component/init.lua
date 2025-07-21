---@class eve.ux.nvimbar.component.__mods
local __mods = {
  ai = "eve.ux.nvimbar.component.ai",
  buf = "eve.ux.nvimbar.component.buf",
  cwd = "eve.ux.nvimbar.component.cwd",
  devmode = "eve.ux.nvimbar.component.devmode",
  dir = "eve.ux.nvimbar.component.dir",
  file = "eve.ux.nvimbar.component.file",
  git = "eve.ux.nvimbar.component.git",
  host = "eve.ux.nvimbar.component.host",
  lsp = "eve.ux.nvimbar.component.lsp",
  nvim = "eve.ux.nvimbar.component.nvim",
  picker = "eve.ux.nvimbar.component.picker",
  plugin = "eve.ux.nvimbar.component.plugin",
  python = "eve.ux.nvimbar.component.python",
  sidebar = "eve.ux.nvimbar.component.sidebar",
  term = "eve.ux.nvimbar.component.term",
}

---@class eve.ux.nvimbar.component
---@field public __mods                 eve.ux.nvimbar.component.__mods
---
---@field public ai                     eve.ux.nvimbar.component.ai
---@field public buf                    eve.ux.nvimbar.component.buf
---@field public cwd                    eve.ux.nvimbar.component.cwd
---@field public devmode                eve.ux.nvimbar.component.devmode
---@field public dir                    eve.ux.nvimbar.component.dir
---@field public file                   eve.ux.nvimbar.component.file
---@field public git                    eve.ux.nvimbar.component.git
---@field public host                   eve.ux.nvimbar.component.host
---@field public lsp                    eve.ux.nvimbar.component.lsp
---@field public nvim                   eve.ux.nvimbar.component.nvim
---@field public picker                 eve.ux.nvimbar.component.picker
---@field public plugin                 eve.ux.nvimbar.component.plugin
---@field public python                 eve.ux.nvimbar.component.python
---@field public sidebar                eve.ux.nvimbar.component.sidebar
---@field public term                   eve.ux.nvimbar.component.term
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
