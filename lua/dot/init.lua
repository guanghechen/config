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

---@class dot.__mods
local __mods = {
  env = "dot.env",
  filetype = "dot.filetype",
  icon = "dot.icon",
  var = "dot.var",
}

---@class dot
---@field public __mods                 dot.__mods
---@field public lang                   dot.lang
---
---@field public env                    dot.env
---@field public filetype               dot.filetype
---@field public icon                   dot.icon
---@field public var                    dot.var
local M = setmetatable({
  __mods = __mods,
  lang = lang,
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
