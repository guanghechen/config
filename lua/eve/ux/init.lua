---@class eve.ux.__mods
local __mods = {
  Nvimbar = "eve.ux.nvimbar",
  Printer = "eve.ux.printer",
  Terminal = "eve.ux.terminal",
  Textarea = "eve.ux.textarea",
}

---@class eve.ux
---@field public __mods                 eve.ux.__mods
---
---@field public Nvimbar                eve.ux.Nvimbar
---@field public Printer                eve.ux.Printer
---@field public Terminal               eve.ux.Terminal
---@field public Textarea               eve.ux.Textarea
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
