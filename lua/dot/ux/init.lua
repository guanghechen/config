---@class dot.ux.__mods
local __mods = {
  Select = "dot.ux.select",
  Setting = "dot.ux.setting",
  Textarea = "dot.ux.textarea",
}

---@class dot.ux
---@field public __mods                 dot.ux.__mods
---
---@field public Select                 dot.ux.Select
---@field public Setting                dot.ux.Setting
---@field public Textarea               dot.ux.Textarea
local M = setmetatable({ __mods = __mods }, {
  __index = function(t, k)
    local m = __mods[k] ---@type string|nil
    if m == nil then
      return rawget(t, k)
    end
    return require(m)
  end,
})

return M
