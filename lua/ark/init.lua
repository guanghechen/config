---@class ark.theme.scheme.__mods
local theme_scheme__mods = {
  ["catppuccin-frappe"] = "ark.theme.scheme.catppuccin-frappe",
  ["catppuccin-latte"] = "ark.theme.scheme.catppuccin-latte",
  ["catppuccin-macchiato"] = "ark.theme.scheme.catppuccin-macchiato",
  ["catppuccin-mocha"] = "ark.theme.scheme.catppuccin-mocha",
  ["gruvbox-dark"] = "ark.theme.scheme.gruvbox-dark",
  ["gruvbox-light"] = "ark.theme.scheme.gruvbox-light",
  ["nord"] = "ark.theme.scheme.nord",
  ["onehalf-dark"] = "ark.theme.scheme.onehalf-dark",
  ["onehalf-light"] = "ark.theme.scheme.onehalf-light",
  ["rosepine-dawn"] = "ark.theme.scheme.rosepine-dawn",
  ["rosepine-main"] = "ark.theme.scheme.rosepine-main",
  ["rosepine-moon"] = "ark.theme.scheme.rosepine-moon",
  ["tokyonight-day"] = "ark.theme.scheme.tokyonight-day",
  ["tokyonight-moon"] = "ark.theme.scheme.tokyonight-moon",
  ["tokyonight-night"] = "ark.theme.scheme.tokyonight-night",
  ["tokyonight-storm"] = "ark.theme.scheme.tokyonight-storm",
  ["vsc-dark-modern"] = "ark.theme.scheme.vsc-dark-modern",
  ["vsc-light-modern"] = "ark.theme.scheme.vsc-light-modern",
}

---@class ark.theme.scheme
---@field public __mods                 ark.theme.scheme.__mods
---@field public ["catppuccin-frappe"]  stl.t.theme.IScheme
---@field public ["catppuccin-latte"]   stl.t.theme.IScheme
---@field public ["catppuccin-macchiato"] stl.t.theme.IScheme
---@field public ["catppuccin-mocha"]   stl.t.theme.IScheme
---@field public ["gruvbox-dark"]       stl.t.theme.IScheme
---@field public ["gruvbox-light"]      stl.t.theme.IScheme
---@field public ["nord"]               stl.t.theme.IScheme
---@field public ["onehalf-dark"]       stl.t.theme.IScheme
---@field public ["onehalf-light"]      stl.t.theme.IScheme
---@field public ["rosepine-dawn"]      stl.t.theme.IScheme
---@field public ["rosepine-main"]      stl.t.theme.IScheme
---@field public ["rosepine-moon"]      stl.t.theme.IScheme
---@field public ["tokyonight-day"]     stl.t.theme.IScheme
---@field public ["tokyonight-moon"]    stl.t.theme.IScheme
---@field public ["tokyonight-night"]   stl.t.theme.IScheme
---@field public ["tokyonight-storm"]   stl.t.theme.IScheme
---@field public ["vsc-dark-modern"]    stl.t.theme.IScheme
---@field public ["vsc-light-modern"]   stl.t.theme.IScheme
local theme_scheme = setmetatable({ __mods = theme_scheme__mods }, {
  __index = function(t, k)
    local m = theme_scheme__mods[k] ---@type string|nil
    if m == nil then
      return rawget(t, k)
    end
    return require(m)
  end,
})

----------------------------------------------------------------------------------------------------

---@class ark.theme.hlgroup.__mods
local theme_hlgroup__mods = {
  basic = "ark.theme.hlgroup.basic",
  common = "ark.theme.hlgroup.common",
  lsp = "ark.theme.hlgroup.lsp",
  module = "ark.theme.hlgroup.module",
  nvimbar = "ark.theme.hlgroup.nvimbar",
  plugin = "ark.theme.hlgroup.plugin",
  treesitter = "ark.theme.hlgroup.treesitter",
  widget = "ark.theme.hlgroup.widget",
}

---@class ark.theme.hlgroup
---@field public __mods                 ark.theme.hlgroup.__mods
---@field public basic                  ark.theme.hlgroup.basic
---@field public common                 ark.theme.hlgroup.common
---@field public lsp                    ark.theme.hlgroup.lsp
---@field public module                 ark.theme.hlgroup.module
---@field public nvimbar                ark.theme.hlgroup.nvimbar
---@field public plugin                 ark.theme.hlgroup.plugin
---@field public treesitter             ark.theme.hlgroup.treesitter
---@field public widget                 ark.theme.hlgroup.widget
local theme_hlgroup = setmetatable({ __mods = theme_hlgroup__mods }, {
  __index = function(t, k)
    local m = theme_hlgroup__mods[k] ---@type string|nil
    if m == nil then
      return rawget(t, k)
    end
    return require(m)
  end,
})

----------------------------------------------------------------------------------------------------

---@class ark.theme.__mods
local theme__mods = {}

---@class ark.theme
---@field public __mods                 ark.theme.__mods
---@field public hlgroup                ark.theme.hlgroup
---@field public scheme                 ark.theme.scheme
local theme = setmetatable({
  __mods = theme__mods,
  hlgroup = theme_hlgroup,
  scheme = theme_scheme,
}, {
  __index = function(t, k)
    local m = theme__mods[k] ---@type string|nil
    if m == nil then
      return rawget(t, k)
    end
    return require(m)
  end,
})

----------------------------------------------------------------------------------------------------

---@class ark.view.IView
---@field public fullname               string
---@field public nsnr                   integer
---@field public clear                  fun(self: ark.view.IView): ark.view.IView
---@field public dispose                fun(self: ark.view.IView): nil
---@field public isdisposed             fun(self: ark.view.IView): boolean
---@field public render                 fun(self: ark.view.IView, bufnr: integer, force: boolean): ark.view.IView

---@class ark.view.__mods
local view__mods = {
  Plainfile = "ark.view.plainfile",
  Printer = "ark.view.printer",
  Tree = "ark.view.tree",
}

---@class ark.view
---@field public __mods                 ark.view.__mods
---@field public Plainfile              ark.view.Plainfile
---@field public Printer                ark.view.Printer
---@field public Tree                   ark.view.Tree
local view = setmetatable({ __mods = view__mods }, {
  __index = function(t, k)
    local m = view__mods[k] ---@type string|nil
    if m == nil then
      return rawget(t, k)
    end
    return require(m)
  end,
})

----------------------------------------------------------------------------------------------------

---@class ark.__mods
local __mods = {
  anim = "ark.anim",
  box = "ark.box",
  fs = "ark.fs",
  G = "ark.G",
  var = "ark.var",
  vim = "ark.vim",
}

---@class ark
---@field public __mods                 ark.__mods
---@field public anim                   ark.anim
---@field public box                    ark.box
---@field public fs                     ark.fs
---@field public G                      ark.G
---@field public theme                  ark.theme
---@field public var                    ark.var
---@field public view                   ark.view
---@field public vim                    ark.vim
local M = setmetatable({
  __mods = __mods,
  theme = theme,
  view = view,
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
