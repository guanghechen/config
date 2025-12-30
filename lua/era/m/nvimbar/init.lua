---@class era.m.nvimbar.IRawComponent
---@field public atomic                 boolean
---@field public name                   string
---@field public tight                  ?boolean
---@field public condition              ?fun(context: era.m.nvimbar.INvimbarContext, remain_width: integer): boolean
---@field public render                 fun(context: era.m.nvimbar.INvimbarContext, remain_width: integer): string, string, boolean
---@field public will_change            ?fun(context: era.m.nvimbar.INvimbarContext, prev_context: era.m.nvimbar.INvimbarContext|nil, remain_width: integer): boolean

---@class era.m.nvimbar.IComponent
---@field public last_render_context    era.m.nvimbar.INvimbarContext|nil
---@field public last_result_full       boolean
---@field public last_result_hltext     string
---@field public last_result_text       string
---@field public last_result_width      integer
---@field public atomic                 boolean
---@field public name                   string
---@field public position               dot.e.NvimbarCompPosition
---@field public priority               integer
---@field public tight                  boolean
---@field public condition              fun(context: era.m.nvimbar.INvimbarContext, remain_width: integer): boolean
---@field public render                 fun(context: era.m.nvimbar.INvimbarContext, remain_width: integer): string, string, boolean
---@field public will_change            fun(context: era.m.nvimbar.INvimbarContext, prev_context: era.m.nvimbar.INvimbarContext|nil, remain_width: integer): boolean

---@class era.m.nvimbar.component.__mods
local __component__mods = {
  ai = "era.m.nvimbar.component.ai",
  buf = "era.m.nvimbar.component.buf",
  copilot = "era.m.nvimbar.component.copilot",
  cwd = "era.m.nvimbar.component.cwd",
  devmode = "era.m.nvimbar.component.devmode",
  dir = "era.m.nvimbar.component.dir",
  explorer = "era.m.nvimbar.component.explorer",
  file = "era.m.nvimbar.component.file",
  git = "era.m.nvimbar.component.git",
  host = "era.m.nvimbar.component.host",
  lint = "era.m.nvimbar.component.lint",
  lsp = "era.m.nvimbar.component.lsp",
  notepad = "era.m.nvimbar.component.notepad",
  nvim = "era.m.nvimbar.component.nvim",
  picker = "era.m.nvimbar.component.picker",
  python = "era.m.nvimbar.component.python",
  sidebar = "era.m.nvimbar.component.sidebar",
  term = "era.m.nvimbar.component.term",
}

---@class era.m.nvimbar.component
---@field public __mods                 era.m.nvimbar.component.__mods
---@field public ai                     era.m.nvimbar.component.ai
---@field public buf                    era.m.nvimbar.component.buf
---@field public copilot                era.m.nvimbar.component.copilot
---@field public cwd                    era.m.nvimbar.component.cwd
---@field public devmode                era.m.nvimbar.component.devmode
---@field public dir                    era.m.nvimbar.component.dir
---@field public explorer               era.m.nvimbar.component.explorer
---@field public file                   era.m.nvimbar.component.file
---@field public git                    era.m.nvimbar.component.git
---@field public host                   era.m.nvimbar.component.host
---@field public lint                   era.m.nvimbar.component.lint
---@field public lsp                    era.m.nvimbar.component.lsp
---@field public notepad                era.m.nvimbar.component.notepad
---@field public nvim                   era.m.nvimbar.component.nvim
---@field public picker                 era.m.nvimbar.component.picker
---@field public python                 era.m.nvimbar.component.python
---@field public sidebar                era.m.nvimbar.component.sidebar
---@field public term                   era.m.nvimbar.component.term
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

---@class era.m.nvimbar.__mods
local __mods = {
  Nvimbar = "era.m.nvimbar.nvimbar",
}

---@class era.m.nvimbar
---@field public __mods                 era.m.nvimbar.__mods
---@field public component              era.m.nvimbar.component
---@field public Nvimbar                era.m.nvimbar.Nvimbar
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
