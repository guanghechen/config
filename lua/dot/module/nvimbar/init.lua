---@class dot.module.nvimbar.IRawComponent
---@field public atomic                 boolean
---@field public name                   string
---@field public tight                  ?boolean
---@field public condition              ?fun(context: dot.module.nvimbar.INvimbarContext, remain_width: integer): boolean
---@field public render                 fun(context: dot.module.nvimbar.INvimbarContext, remain_width: integer): string, string, boolean
---@field public will_change            ?fun(context: dot.module.nvimbar.INvimbarContext, prev_context: dot.module.nvimbar.INvimbarContext|nil, remain_width: integer): boolean

---@class dot.module.nvimbar.IComponent
---@field public last_render_context    dot.module.nvimbar.INvimbarContext|nil
---@field public last_result_full       boolean
---@field public last_result_hltext     string
---@field public last_result_text       string
---@field public last_result_width      integer
---@field public atomic                 boolean
---@field public name                   string
---@field public position               dot.e.NvimbarCompPosition
---@field public priority               integer
---@field public tight                  boolean
---@field public condition              fun(context: dot.module.nvimbar.INvimbarContext, remain_width: integer): boolean
---@field public render                 fun(context: dot.module.nvimbar.INvimbarContext, remain_width: integer): string, string, boolean
---@field public will_change            fun(context: dot.module.nvimbar.INvimbarContext, prev_context: dot.module.nvimbar.INvimbarContext|nil, remain_width: integer): boolean

---@class dot.module.nvimbar.component.__mods
local __component__mods = {
  ai = "dot.module.nvimbar.component.ai",
  buf = "dot.module.nvimbar.component.buf",
  copilot = "dot.module.nvimbar.component.copilot",
  cwd = "dot.module.nvimbar.component.cwd",
  devmode = "dot.module.nvimbar.component.devmode",
  dir = "dot.module.nvimbar.component.dir",
  explorer = "dot.module.nvimbar.component.explorer",
  file = "dot.module.nvimbar.component.file",
  git = "dot.module.nvimbar.component.git",
  host = "dot.module.nvimbar.component.host",
  lint = "dot.module.nvimbar.component.lint",
  lsp = "dot.module.nvimbar.component.lsp",
  notepad = "dot.module.nvimbar.component.notepad",
  nvim = "dot.module.nvimbar.component.nvim",
  picker = "dot.module.nvimbar.component.picker",
  python = "dot.module.nvimbar.component.python",
  sidebar = "dot.module.nvimbar.component.sidebar",
  term = "dot.module.nvimbar.component.term",
}

---@class dot.module.nvimbar.component
---@field public __mods                 dot.module.nvimbar.component.__mods
---@field public ai                     dot.module.nvimbar.component.ai
---@field public buf                    dot.module.nvimbar.component.buf
---@field public copilot                dot.module.nvimbar.component.copilot
---@field public cwd                    dot.module.nvimbar.component.cwd
---@field public devmode                dot.module.nvimbar.component.devmode
---@field public dir                    dot.module.nvimbar.component.dir
---@field public explorer               dot.module.nvimbar.component.explorer
---@field public file                   dot.module.nvimbar.component.file
---@field public git                    dot.module.nvimbar.component.git
---@field public host                   dot.module.nvimbar.component.host
---@field public lint                   dot.module.nvimbar.component.lint
---@field public lsp                    dot.module.nvimbar.component.lsp
---@field public notepad                dot.module.nvimbar.component.notepad
---@field public nvim                   dot.module.nvimbar.component.nvim
---@field public picker                 dot.module.nvimbar.component.picker
---@field public python                 dot.module.nvimbar.component.python
---@field public sidebar                dot.module.nvimbar.component.sidebar
---@field public term                   dot.module.nvimbar.component.term
local component = setmetatable({
  __mods = __component__mods,
}, {
  __index = function(t, k)
    local m = __component__mods[k] ---@type string|nil
    if m == nil then
      return rawget(t, k)
    end
    return require(m)
  end,
})

----------------------------------------------------------------------------------------------------

---@class dot.module.nvimbar.__mods
local __mods = {
  Nvimbar = "dot.module.nvimbar.nvimbar",
}

---@class dot.module.nvimbar
---@field public __mods                 dot.module.nvimbar.__mods
---@field public component              dot.module.nvimbar.component
---@field public Nvimbar                dot.module.nvimbar.Nvimbar
local M = setmetatable({
  __mods = __mods,
  component = component,
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
