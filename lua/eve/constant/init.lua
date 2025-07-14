---@class eve.constant.__mods
local __mods = {
  diagnostic = "eve.constant.diagnostic",
}

---@class eve.constant.hlgroup.__mods
local hlgroup__mods = {
  basic = "eve.constant.hlgroup.basic",
  common = "eve.constant.hlgroup.common",
  nvimbar = "eve.constant.hlgroup.nvimbar",
  plugin = "eve.constant.hlgroup.plugin",
  treesitter = "eve.constant.hlgroup.treesitter",
  widget = "eve.constant.hlgroup.widget",
}

---@class eve.constant.hlgroup
---@field public __mods                 eve.constant.hlgroup.__mods
---@field public basic                  eve.constant.hlgroup.basic
---@field public common                 eve.constant.hlgroup.common
---@field public nvimbar                eve.constant.hlgroup.nvimbar
---@field public plugin                 eve.constant.hlgroup.plugin
---@field public widget                 eve.constant.hlgroup.widget
local hlgroup = setmetatable({
  __mods = hlgroup__mods,
}, {
  __index = function(t, k)
    local m = hlgroup__mods[k] ---@type string|nil
    if m == nil then
      return rawget(t, k)
    end
    return require(m)
  end,
})

---@class eve.constant.lang.__mods
local lang__mods = {
  python = "eve.constant.lang.python",
  tailwind = "eve.constant.lang.tailwind",
}

---@class eve.constant.lang
---@field public __mods                 eve.constant.lang.__mods
---@field public python                 eve.constant.lang.python
---@field public tailwind               eve.constant.lang.tailwind
local lang = setmetatable({
  __mods = lang__mods,
}, {
  __index = function(t, k)
    local m = lang__mods[k] ---@type string|nil
    if m == nil then
      return rawget(t, k)
    end
    return require(m)
  end,
})

---@class eve.constant.theme.__mods
local theme__mods = {
  ["catppuccin-frappe"] = "eve.constant.theme.catppuccin-frappe",
  ["catppuccin-latte"] = "eve.constant.theme.catppuccin-latte",
  ["catppuccin-macchiato"] = "eve.constant.theme.catppuccin-macchiato",
  ["catppuccin-mocha"] = "eve.constant.theme.catppuccin-mocha",
  ["gruvbox-light"] = "eve.constant.theme.gruvbox-light",
  ["gruvbox-dark"] = "eve.constant.theme.gruvbox-dark",
  ["nord"] = "eve.constant.theme.nord",
  ["one-half-light"] = "eve.constant.theme.one-half-light",
  ["one-half-dark"] = "eve.constant.theme.one-half-dark",
  ["rose-pine-main"] = "eve.constant.theme.rose-pine-main",
  ["rose-pine-moon"] = "eve.constant.theme.rose-pine-moon",
  ["rose-pine-dawn"] = "eve.constant.theme.rose-pine-dawn",
}

---@class eve.constant.theme
---@field public __mods                 eve.constant.theme.__mods
---@field public ["catppuccin-frappe"]  std.t.theme.IScheme
---@field public ["catppuccin-latte"]   std.t.theme.IScheme
---@field public ["catppuccin-macchiato"] std.t.theme.IScheme
---@field public ["catppuccin-mocha"]   std.t.theme.IScheme
---@field public ["gruvbox-light"]      std.t.theme.IScheme
---@field public ["gruvbox-dark"]       std.t.theme.IScheme
---@field public ["nord"]               std.t.theme.IScheme
---@field public ["one-half-light"]     std.t.theme.IScheme
---@field public ["one-half-dark"]      std.t.theme.IScheme
---@field public ["rose-pine-main"]     std.t.theme.IScheme
---@field public ["rose-pine-moon"]     std.t.theme.IScheme
---@field public ["rose-pine-dawn"]     std.t.theme.IScheme
local theme = setmetatable({
  __mods = theme__mods,
}, {
  __index = function(t, k)
    local m = theme__mods[k] ---@type string|nil
    if m == nil then
      return rawget(t, k)
    end
    return require(m)
  end,
})

---@class eve.constant
---@field public __mods                 eve.constant.__mods
---@field public hlgroup                eve.constant.hlgroup
---@field public lang                   eve.constant.lang
---@field public theme                  eve.constant.theme
---
---@field public diagnostic             eve.constant.diagnostic
local M = setmetatable({
  __mods = __mods,
  hlgroup = hlgroup,
  lang = lang,
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
