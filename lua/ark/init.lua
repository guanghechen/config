---@class ark.c.__mods
local c__mods = {
  Disposable = "ark.c.disposable",
}

---@class ark.c
---@field public __mods                 ark.c.__mods
---@field public Disposable             ark.c.Disposable
local c = setmetatable({ __mods = c__mods }, {
  __index = function(t, k)
    local m = c__mods[k] ---@type string|nil
    if m == nil then
      return rawget(t, k)
    end
    return require(m)
  end,
})

----------------------------------------------------------------------------------------------------

---@class ark.__mods
local __mods = {
  color = "ark.external.color",
  easing = "ark.external.easing",
  reporter = "ark.reporter",
}

---@class ark
---@field public __mods                 ark.__mods
---@field public c                      ark.c
---@field public color                  ark.external.color
---@field public easing                 ark.external.easing
---@field public reporter               ark.reporter
local M = setmetatable({
  __mods = __mods,
  c = c,
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
