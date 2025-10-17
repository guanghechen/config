---@class eve.ux.widget.__mods
local __mods = {
  Notepad = "eve.ux.widget.notepad",
  Terminal = "eve.ux.widget.terminal",
}

---@class eve.ux.widget
---@field public __mods                 eve.ux.widget.__mods
---
---@field public Notepad                eve.ux.widget.Notepad
---@field public Terminal               eve.ux.widget.Terminal
local M = setmetatable({
  __mods = __mods,
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
