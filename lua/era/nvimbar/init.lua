---@class era.nvimbar.IRawComponent
---@field public atomic                 boolean
---@field public name                   string
---@field public tight                  ?boolean
---@field public condition              ?fun(context: era.nvimbar.INvimbarContext, remain_width: integer): boolean
---@field public render                 fun(context: era.nvimbar.INvimbarContext, remain_width: integer): string, string, boolean
---@field public will_change            ?fun(context: era.nvimbar.INvimbarContext, prev_context: era.nvimbar.INvimbarContext|nil, remain_width: integer): boolean

---@class era.nvimbar.IComponent
---@field public last_render_context    era.nvimbar.INvimbarContext|nil
---@field public last_result_full       boolean
---@field public last_result_hltext     string
---@field public last_result_text       string
---@field public last_result_width      integer
---@field public atomic                 boolean
---@field public name                   string
---@field public position               dot.e.NvimbarCompPosition
---@field public priority               integer
---@field public tight                  boolean
---@field public condition              fun(context: era.nvimbar.INvimbarContext, remain_width: integer): boolean
---@field public render                 fun(context: era.nvimbar.INvimbarContext, remain_width: integer): string, string, boolean
---@field public will_change            fun(context: era.nvimbar.INvimbarContext, prev_context: era.nvimbar.INvimbarContext|nil, remain_width: integer): boolean

---@class era.nvimbar.component.__mods
local __component__mods = {
  ai = "era.nvimbar.component.ai",
  buf = "era.nvimbar.component.buf",
  copilot = "era.nvimbar.component.copilot",
  cwd = "era.nvimbar.component.cwd",
  devmode = "era.nvimbar.component.devmode",
  dir = "era.nvimbar.component.dir",
  explorer = "era.nvimbar.component.explorer",
  file = "era.nvimbar.component.file",
  git = "era.nvimbar.component.git",
  host = "era.nvimbar.component.host",
  lint = "era.nvimbar.component.lint",
  lsp = "era.nvimbar.component.lsp",
  notepad = "era.nvimbar.component.notepad",
  nvim = "era.nvimbar.component.nvim",
  picker = "era.nvimbar.component.picker",
  python = "era.nvimbar.component.python",
  sidebar = "era.nvimbar.component.sidebar",
  term = "era.nvimbar.component.term",
}

---@class era.nvimbar.component
---@field public __mods                 era.nvimbar.component.__mods
---@field public ai                     era.nvimbar.component.ai
---@field public buf                    era.nvimbar.component.buf
---@field public copilot                era.nvimbar.component.copilot
---@field public cwd                    era.nvimbar.component.cwd
---@field public devmode                era.nvimbar.component.devmode
---@field public dir                    era.nvimbar.component.dir
---@field public explorer               era.nvimbar.component.explorer
---@field public file                   era.nvimbar.component.file
---@field public git                    era.nvimbar.component.git
---@field public host                   era.nvimbar.component.host
---@field public lint                   era.nvimbar.component.lint
---@field public lsp                    era.nvimbar.component.lsp
---@field public notepad                era.nvimbar.component.notepad
---@field public nvim                   era.nvimbar.component.nvim
---@field public picker                 era.nvimbar.component.picker
---@field public python                 era.nvimbar.component.python
---@field public sidebar                era.nvimbar.component.sidebar
---@field public term                   era.nvimbar.component.term
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

---@class era.nvimbar.__mods
local __mods = {
  Nvimbar = "era.nvimbar.nvimbar",
}

---@class era.nvimbar
---@field public __mods                 era.nvimbar.__mods
---@field public component              era.nvimbar.component
---@field public Nvimbar                era.nvimbar.Nvimbar
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
