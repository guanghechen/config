---@class ux.nvimbar.component.__mods
local __mods = {
  ai = "ux.nvimbar.component.ai",
  buf = "ux.nvimbar.component.buf",
  copilot = "ux.nvimbar.component.copilot",
  cwd = "ux.nvimbar.component.cwd",
  devmode = "ux.nvimbar.component.devmode",
  dir = "ux.nvimbar.component.dir",
  file = "ux.nvimbar.component.file",
  git = "ux.nvimbar.component.git",
  host = "ux.nvimbar.component.host",
  lint = "ux.nvimbar.component.lint",
  lsp = "ux.nvimbar.component.lsp",
  notepad = "ux.nvimbar.component.notepad",
  nvim = "ux.nvimbar.component.nvim",
  picker = "ux.nvimbar.component.picker",
  plugin = "ux.nvimbar.component.plugin",
  python = "ux.nvimbar.component.python",
  sidebar = "ux.nvimbar.component.sidebar",
  term = "ux.nvimbar.component.term",
}

---@class ux.nvimbar.component
---@field public __mods                 ux.nvimbar.component.__mods
---
---@field public ai                     ux.nvimbar.component.ai
---@field public buf                    ux.nvimbar.component.buf
---@field public copilot                ux.nvimbar.component.copilot
---@field public cwd                    ux.nvimbar.component.cwd
---@field public devmode                ux.nvimbar.component.devmode
---@field public dir                    ux.nvimbar.component.dir
---@field public file                   ux.nvimbar.component.file
---@field public git                    ux.nvimbar.component.git
---@field public host                   ux.nvimbar.component.host
---@field public lint                   ux.nvimbar.component.lint
---@field public lsp                    ux.nvimbar.component.lsp
---@field public notepad                ux.nvimbar.component.notepad
---@field public nvim                   ux.nvimbar.component.nvim
---@field public picker                 ux.nvimbar.component.picker
---@field public plugin                 ux.nvimbar.component.plugin
---@field public python                 ux.nvimbar.component.python
---@field public sidebar                ux.nvimbar.component.sidebar
---@field public term                   ux.nvimbar.component.term
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
