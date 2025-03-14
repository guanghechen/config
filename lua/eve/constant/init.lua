---@class eve.constant.__mods
local __mods = {
  filetype = "eve.constant.filetype",
  hint = "eve.constant.hint",
  icon = "eve.constant.icon",
  setting = "eve.constant.setting",
  sign = "eve.constant.sign",
}

---@class eve.constant
---@field public __mods                 eve.constant.__mods
---
---@field public filetype               eve.constant.filetype
---@field public hint                   eve.constant.hint
---@field public icon                   eve.constant.icon
---@field public setting                eve.constant.setting
---@field public sign                   eve.constant.sign
---@field public varname                eve.constant.varname
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
