---@class dot.dict.__mods
local __dict__mods = {
  en = "dot.dict.en",
}

---@class dot.dict
---@field public __mods                 dot.dict.__mods
---@field public en                     { [1]: string, [2]: string }[]
local dict = setmetatable({
  __mods = __dict__mods,
}, {
  __index = function(t, k)
    local m = __dict__mods[k] ---@type string|nil
    if m == nil then
      return rawget(t, k)
    end
    return require(m)
  end,
})

----------------------------------------------------------------------------------------------------

---@class dot.lang.__mods
local __lang__mods = {
  python = "dot.lang.python",
  tailwind = "dot.lang.tailwind",
}

---@class dot.lang
---@field public __mods                 dot.lang.__mods
---@field public python                 dot.lang.python
---@field public tailwind               dot.lang.tailwind
local lang = setmetatable({
  __mods = __lang__mods,
}, {
  __index = function(t, k)
    local m = __lang__mods[k] ---@type string|nil
    if m == nil then
      return rawget(t, k)
    end
    return require(m)
  end,
})

----------------------------------------------------------------------------------------------------

---@class dot.theme.hlgroup.__mods
local __theme_hlgroup__mods = {
  basic = "dot.theme.hlgroup.basic",
  common = "dot.theme.hlgroup.common",
  lsp = "dot.theme.hlgroup.lsp",
  nvimbar = "dot.theme.hlgroup.nvimbar",
  plugin = "dot.theme.hlgroup.plugin",
  treesitter = "dot.theme.hlgroup.treesitter",
  widget = "dot.theme.hlgroup.widget",
}

---@class dot.theme.hlgroup
---@field public __mods                 dot.theme.hlgroup.__mods
---@field public basic                  dot.theme.hlgroup.basic
---@field public common                 dot.theme.hlgroup.common
---@field public lsp                    dot.theme.hlgroup.lsp
---@field public nvimbar                dot.theme.hlgroup.nvimbar
---@field public plugin                 dot.theme.hlgroup.plugin
---@field public treesitter             dot.theme.hlgroup.treesitter
---@field public widget                 dot.theme.hlgroup.widget
local hlgroup = setmetatable({
  __mods = __theme_hlgroup__mods,
}, {
  __index = function(t, k)
    local m = __theme_hlgroup__mods[k] ---@type string|nil
    if m == nil then
      return rawget(t, k)
    end
    return require(m)
  end,
})

----------------------------------------------------------------------------------------------------

---@class dot.theme.scheme.__mods
local __theme_scheme__mods = {
  ["catppuccin-frappe"] = "dot.theme.scheme.catppuccin-frappe",
  ["catppuccin-latte"] = "dot.theme.scheme.catppuccin-latte",
  ["catppuccin-macchiato"] = "dot.theme.scheme.catppuccin-macchiato",
  ["catppuccin-mocha"] = "dot.theme.scheme.catppuccin-mocha",
  ["gruvbox-dark"] = "dot.theme.scheme.gruvbox-dark",
  ["gruvbox-light"] = "dot.theme.scheme.gruvbox-light",
  ["nord"] = "dot.theme.scheme.nord",
  ["onehalf-dark"] = "dot.theme.scheme.onehalf-dark",
  ["onehalf-light"] = "dot.theme.scheme.onehalf-light",
  ["rosepine-dawn"] = "dot.theme.scheme.rosepine-dawn",
  ["rosepine-main"] = "dot.theme.scheme.rosepine-main",
  ["rosepine-moon"] = "dot.theme.scheme.rosepine-moon",
  ["tokyonight-day"] = "dot.theme.scheme.tokyonight-day",
  ["tokyonight-moon"] = "dot.theme.scheme.tokyonight-moon",
  ["tokyonight-night"] = "dot.theme.scheme.tokyonight-night",
  ["tokyonight-storm"] = "dot.theme.scheme.tokyonight-storm",
  ["vsc-dark-modern"] = "dot.theme.scheme.vsc-dark-modern",
  ["vsc-light-modern"] = "dot.theme.scheme.vsc-light-modern",
}

---@class dot.theme.scheme
---@field public __mods                 dot.theme.scheme.__mods
---@field public ["catppuccin-frappe"]  dot.t.theme.IScheme
---@field public ["catppuccin-latte"]   dot.t.theme.IScheme
---@field public ["catppuccin-macchiato"] dot.t.theme.IScheme
---@field public ["catppuccin-mocha"]   dot.t.theme.IScheme
---@field public ["gruvbox-dark"]       dot.t.theme.IScheme
---@field public ["gruvbox-light"]      dot.t.theme.IScheme
---@field public ["nord"]               dot.t.theme.IScheme
---@field public ["onehalf-dark"]       dot.t.theme.IScheme
---@field public ["onehalf-light"]      dot.t.theme.IScheme
---@field public ["rosepine-dawn"]      dot.t.theme.IScheme
---@field public ["rosepine-main"]      dot.t.theme.IScheme
---@field public ["rosepine-moon"]      dot.t.theme.IScheme
---@field public ["tokyonight-day"]     dot.t.theme.IScheme
---@field public ["tokyonight-moon"]    dot.t.theme.IScheme
---@field public ["tokyonight-night"]   dot.t.theme.IScheme
---@field public ["tokyonight-storm"]   dot.t.theme.IScheme
---@field public ["vsc-dark-modern"]    dot.t.theme.IScheme
---@field public ["vsc-light-modern"]   dot.t.theme.IScheme
local scheme = setmetatable({
  __mods = __theme_scheme__mods,
}, {
  __index = function(t, k)
    local m = __theme_scheme__mods[k] ---@type string|nil
    if m == nil then
      return rawget(t, k)
    end
    return require(m)
  end,
})

----------------------------------------------------------------------------------------------------

---@class dot.theme.__mods
local __theme__mods = {
  Namespace = "dot.theme.namespace",
}

---@class dot.theme
---@field public __mods                 dot.theme.__mods
---@field public hlgroup                dot.theme.hlgroup
---@field public scheme                 dot.theme.scheme
---@field public Namespace              dot.theme.Namespace
local theme = setmetatable({
  __mods = __theme__mods,
  hlgroup = hlgroup,
  scheme = scheme,
}, {
  __index = function(t, k)
    local m = __theme__mods[k] ---@type string|nil
    if m == nil then
      return rawget(t, k)
    end
    return require(m)
  end,
})

----------------------------------------------------------------------------------------------------

---@class dot.state.__mods
local __state__mods = {
  git = "dot.state.git",
  maximized = "dot.state.maximized",
  notepad = "dot.state.notepad",
  qflist = "dot.state.qflist",
  status = "dot.state.status",
  widget = "dot.state.widget",
}

---@class dot.state
---@field public __mods                 dot.state.__mods
---@field public git                    dot.state.git
---@field public maximized              dot.state.maximized
---@field public notepad                dot.state.notepad
---@field public qflist                 dot.state.qflist
---@field public status                 dot.state.status
---@field public widget                 dot.state.widget
local state = setmetatable({
  __mods = __state__mods,
}, {
  __index = function(t, k)
    local m = __state__mods[k] ---@type string|nil
    if m == nil then
      return rawget(t, k)
    end
    return require(m)
  end,
})

----------------------------------------------------------------------------------------------------

---@class dot.__mods
local __mods = {
  G = "dot.G",
  buf = "dot.buf",
  command = "dot.command",
  context = "dot.context",
  fileicon = "dot.fileicon",
  filetype = "dot.filetype",
  icon = "dot.icon",
  path = "dot.path",
  session = "dot.session",
  shell = "dot.shell",
  tab = "dot.tab",
  var = "dot.var",
  win = "dot.win",
}

---@class dot
---@field public __mods                 dot.__mods
---@field public command                dot.command
---@field public context                dot.context
---@field public dict                   dot.dict
---@field public lang                   dot.lang
---@field public session                dot.session
---@field public state                  dot.state
---@field public theme                  dot.theme
---
---@field public G                      dot.G
---@field public buf                    dot.buf
---@field public fileicon               dot.fileicon
---@field public filetype               dot.filetype
---@field public icon                   dot.icon
---@field public path                   dot.path
---@field public shell                  dot.shell
---@field public tab                    dot.tab
---@field public var                    dot.var
---@field public win                    dot.win
local M = setmetatable({
  __mods = __mods,
  dict = dict,
  lang = lang,
  state = state,
  theme = theme,
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
