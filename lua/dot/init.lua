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

---@class dot.theme.__mods
local __theme__mods = {
  ["catppuccin-frappe"] = "dot.theme.catppuccin-frappe",
  ["catppuccin-latte"] = "dot.theme.catppuccin-latte",
  ["catppuccin-macchiato"] = "dot.theme.catppuccin-macchiato",
  ["catppuccin-mocha"] = "dot.theme.catppuccin-mocha",
  ["gruvbox-dark"] = "dot.theme.gruvbox-dark",
  ["gruvbox-light"] = "dot.theme.gruvbox-light",
  ["nord"] = "dot.theme.nord",
  ["onehalf-dark"] = "dot.theme.onehalf-dark",
  ["onehalf-light"] = "dot.theme.onehalf-light",
  ["rosepine-dawn"] = "dot.theme.rosepine-dawn",
  ["rosepine-main"] = "dot.theme.rosepine-main",
  ["rosepine-moon"] = "dot.theme.rosepine-moon",
  ["tokyonight-day"] = "dot.theme.tokyonight-day",
  ["tokyonight-moon"] = "dot.theme.tokyonight-moon",
  ["tokyonight-night"] = "dot.theme.tokyonight-night",
  ["tokyonight-storm"] = "dot.theme.tokyonight-storm",
  ["vsc-dark-modern"] = "dot.theme.vsc-dark-modern",
  ["vsc-light-modern"] = "dot.theme.vsc-light-modern",
}

---@class dot.theme
---@field public __mods                 dot.theme.__mods
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
local theme = setmetatable({
  __mods = __theme__mods,
}, {
  __index = function(t, k)
    local m = __theme__mods[k] ---@type string|nil
    if m == nil then
      return rawget(t, k)
    end
    return require(m)
  end,
})

---@class dot.__mods
local __mods = {
  diagnostic = "dot.diagnostic",
  env = "dot.env",
  fileicon = "dot.fileicon",
  filetype = "dot.filetype",
  icon = "dot.icon",
  var = "dot.var",
}

---@class dot
---@field public __mods                 dot.__mods
---@field public lang                   dot.lang
---@field public theme                  dot.theme
---
---@field public diagnostic             dot.diagnostic
---@field public env                    dot.env
---@field public fileicon               dot.fileicon
---@field public filetype               dot.filetype
---@field public icon                   dot.icon
---@field public var                    dot.var
local M = setmetatable({
  __mods = __mods,
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
