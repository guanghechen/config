---@diagnostic disable-next-line: unused-local
local __module_name__ = "era.m.nvimbar" ---@type string

---@class era.m.nvimbar.ITextSnapshot
---@field public text                   string
---@field public hltext                 string

---@class era.m.nvimbar.INotifyPolicy
---@field public strategy               "immediate"|"debounce"|"throttle"
---@field public interval               ?integer Positive milliseconds for debounce/throttle; omitted for immediate.

--- Refresh owns data acquisition; render only formats the committed snapshot.
---@class era.m.nvimbar.IRawComponent
---@field public name                   string
---@field public tight                  ?boolean
---@field public condition              ?fun(context: era.m.nvimbar.INvimbarContext): boolean
---@field public will_change            ?fun(context: era.m.nvimbar.INvimbarContext, prev_context: era.m.nvimbar.INvimbarContext, snapshot: any): boolean Pure, cheap check before refresh; defaults to true.
---@field public timeout                ?integer
---@field public notify                 ?era.m.nvimbar.INotifyPolicy Defaults to immediate; placement replaces the whole policy.
---@field public refresh                fun(context: era.m.nvimbar.INvimbarContext, token: stl.c.CancellationToken): any|stl.c.Future
---@field public render                 ?fun(snapshot: any, context: era.m.nvimbar.INvimbarContext, remain_width: integer): string, string

---@class era.m.nvimbar.component.__mods
local __component__mods = {
  ai = "era.m.nvimbar.component.ai",
  buf = "era.m.nvimbar.component.buf",
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

--- Mark a typed factory; each runtime owns its initialization and cached definition.
---@param factory                       fun(): era.m.nvimbar.IRawComponent
---@return fun(): era.m.nvimbar.IRawComponent
function component.lazy(factory)
  assert(type(factory) == "function", "Expected a nvimbar component factory")
  return factory
end

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
