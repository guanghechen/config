---@class stl.dict.__mods
local dict__mods = {
  en = "stl.dict.en",
}

---@class stl.dict
---@field public __mods                 stl.dict.__mods
---@field public en                     { [1]: string, [2]: string }[]
local dict = setmetatable({ __mods = dict__mods }, {
  __index = function(t, k)
    local m = dict__mods[k] ---@type string|nil
    if m == nil then
      return rawget(t, k)
    end
    return require(m)
  end,
})

----------------------------------------------------------------------------------------------------

---@class stl.__mods
local __mods = {
  color = "stl.external.color",
  easing = "stl.external.easing",

  env = "stl.env",
  fileicon = "stl.fileicon",
  filetype = "stl.filetype",
  icon = "stl.icon",
  json = "stl.json",
  stdout = "stl.stdout",
}

---@class stl
---@field public __mods                 stl.__mods
---@field public color                  stl.external.color
---@field public easing                 stl.external.easing
---
---@field public dict                   stl.dict
---
---@field public env                    stl.env
---@field public fileicon               stl.fileicon
---@field public filetype               stl.filetype
---@field public icon                   stl.icon
---@field public json                   stl.json
---@field public stdout                 stl.stdout
local M = setmetatable({
  __mods = __mods,
  dict = dict,
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
