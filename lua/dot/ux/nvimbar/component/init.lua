---@class dot.ux.nvimbar.component.__mods
local __mods = {
  ai = "dot.ux.nvimbar.component.ai",
  buf = "dot.ux.nvimbar.component.buf",
  copilot = "dot.ux.nvimbar.component.copilot",
  cwd = "dot.ux.nvimbar.component.cwd",
  devmode = "dot.ux.nvimbar.component.devmode",
  dir = "dot.ux.nvimbar.component.dir",
  file = "dot.ux.nvimbar.component.file",
  git = "dot.ux.nvimbar.component.git",
  host = "dot.ux.nvimbar.component.host",
  lint = "dot.ux.nvimbar.component.lint",
  lsp = "dot.ux.nvimbar.component.lsp",
  notepad = "dot.ux.nvimbar.component.notepad",
  nvim = "dot.ux.nvimbar.component.nvim",
  picker = "dot.ux.nvimbar.component.picker",
  plugin = "dot.ux.nvimbar.component.plugin",
  python = "dot.ux.nvimbar.component.python",
  sidebar = "dot.ux.nvimbar.component.sidebar",
  term = "dot.ux.nvimbar.component.term",
}

---@class dot.ux.nvimbar.component
---@field public __mods                 dot.ux.nvimbar.component.__mods
---
---@field public ai                     dot.ux.nvimbar.component.ai
---@field public buf                    dot.ux.nvimbar.component.buf
---@field public copilot                dot.ux.nvimbar.component.copilot
---@field public cwd                    dot.ux.nvimbar.component.cwd
---@field public devmode                dot.ux.nvimbar.component.devmode
---@field public dir                    dot.ux.nvimbar.component.dir
---@field public file                   dot.ux.nvimbar.component.file
---@field public git                    dot.ux.nvimbar.component.git
---@field public host                   dot.ux.nvimbar.component.host
---@field public lint                   dot.ux.nvimbar.component.lint
---@field public lsp                    dot.ux.nvimbar.component.lsp
---@field public notepad                dot.ux.nvimbar.component.notepad
---@field public nvim                   dot.ux.nvimbar.component.nvim
---@field public picker                 dot.ux.nvimbar.component.picker
---@field public plugin                 dot.ux.nvimbar.component.plugin
---@field public python                 dot.ux.nvimbar.component.python
---@field public sidebar                dot.ux.nvimbar.component.sidebar
---@field public term                   dot.ux.nvimbar.component.term
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
