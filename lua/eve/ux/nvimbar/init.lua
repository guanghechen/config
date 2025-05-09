---@alias eve.ux.nvimbar.PositionEnum
---| 'f_sl'
---| 'f_tl'
---| 'f_wl'

---@class eve.ux.nvimbar.IRawComponent
---@field public atomic                 boolean
---@field public name                   string
---@field public tight                  ?boolean
---@field public condition              ?fun(context: eve.ux.nvimbar.INvimbarContext, remain_width: integer): boolean
---@field public render                 fun(context: eve.ux.nvimbar.INvimbarContext, remain_width: integer): string, string, boolean
---@field public will_change            ?fun(context: eve.ux.nvimbar.INvimbarContext, prev_context: eve.ux.nvimbar.INvimbarContext|nil, remain_width: integer): boolean

---@class eve.ux.nvimbar.IComponent
---@field public last_render_context    eve.ux.nvimbar.INvimbarContext|nil
---@field public last_result_full       boolean
---@field public last_result_hltext     string
---@field public last_result_text       string
---@field public last_result_width      integer
---@field public atomic                 boolean
---@field public name                   string
---@field public position               eve.e.NvimbarCompPosition
---@field public priority               integer
---@field public tight                  boolean
---@field public condition              fun(context: eve.ux.nvimbar.INvimbarContext, remain_width: integer): boolean
---@field public render                 fun(context: eve.ux.nvimbar.INvimbarContext, remain_width: integer): string, string, boolean
---@field public will_change            fun(context: eve.ux.nvimbar.INvimbarContext, prev_context: eve.ux.nvimbar.INvimbarContext|nil, remain_width: integer): boolean

---@class eve.ux.nvimbar.__mods
local __mods = {
  Nvimbar = "eve.ux.nvimbar.nvimbar",
}

---@class eve.ux.nvimbar
---@field public __mods                 eve.ux.nvimbar.__mods
---@field public component              eve.ux.nvimbar.component
---
---@field public Nvimbar                eve.ux.nvimbar.Nvimbar
local M = setmetatable({
  __mods = __mods,
  component = require("eve.ux.nvimbar.component"),
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
