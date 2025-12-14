---@alias dot.ux.nvimbar.PositionEnum
---| "f_sl"
---| "f_tl"
---| "f_wl"

---@class dot.ux.nvimbar.IRawComponent
---@field public atomic                 boolean
---@field public name                   string
---@field public tight                  ?boolean
---@field public condition              ?fun(context: dot.ux.nvimbar.INvimbarContext, remain_width: integer): boolean
---@field public render                 fun(context: dot.ux.nvimbar.INvimbarContext, remain_width: integer): string, string, boolean
---@field public will_change            ?fun(context: dot.ux.nvimbar.INvimbarContext, prev_context: dot.ux.nvimbar.INvimbarContext|nil, remain_width: integer): boolean

---@class dot.ux.nvimbar.IComponent
---@field public last_render_context    dot.ux.nvimbar.INvimbarContext|nil
---@field public last_result_full       boolean
---@field public last_result_hltext     string
---@field public last_result_text       string
---@field public last_result_width      integer
---@field public atomic                 boolean
---@field public name                   string
---@field public position               dot.e.NvimbarCompPosition
---@field public priority               integer
---@field public tight                  boolean
---@field public condition              fun(context: dot.ux.nvimbar.INvimbarContext, remain_width: integer): boolean
---@field public render                 fun(context: dot.ux.nvimbar.INvimbarContext, remain_width: integer): string, string, boolean
---@field public will_change            fun(context: dot.ux.nvimbar.INvimbarContext, prev_context: dot.ux.nvimbar.INvimbarContext|nil, remain_width: integer): boolean

---@class dot.ux.nvimbar.__mods
local __mods = {
  Nvimbar = "dot.ux.nvimbar.nvimbar",
  component = "dot.ux.nvimbar.component",
}

---@class dot.ux.nvimbar
---@field public __mods                 dot.ux.nvimbar.__mods
---@field public component              dot.ux.nvimbar.component
---@field public Nvimbar                dot.ux.nvimbar.Nvimbar
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
