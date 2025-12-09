---@class eve.constant.__mods
local __mods = {}

---@class eve.constant.hlgroup.__mods
local hlgroup__mods = {
  basic = "eve.constant.hlgroup.basic",
  common = "eve.constant.hlgroup.common",
  lsp = "eve.constant.hlgroup.lsp",
  nvimbar = "eve.constant.hlgroup.nvimbar",
  plugin = "eve.constant.hlgroup.plugin",
  treesitter = "eve.constant.hlgroup.treesitter",
  widget = "eve.constant.hlgroup.widget",
}

---@class eve.constant.hlgroup
---@field public __mods                 eve.constant.hlgroup.__mods
---@field public basic                  eve.constant.hlgroup.basic
---@field public common                 eve.constant.hlgroup.common
---@field public lsp                    eve.constant.hlgroup.lsp
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

---@class eve.constant
---@field public __mods                 eve.constant.__mods
---@field public hlgroup                eve.constant.hlgroup
local M = setmetatable({
  __mods = __mods,
  hlgroup = hlgroup,
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
