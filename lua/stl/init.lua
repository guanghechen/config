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
  env = "stl.env",
}

---@class stl
---@field public __mods                 stl.__mods
---@field public dict                   stl.dict
---@field public env                    stl.env
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
