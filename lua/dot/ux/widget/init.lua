---@class dot.ux.widget.__mods
local __mods = {
  Notepad = "dot.ux.widget.notepad",
  Terminal = "dot.ux.widget.terminal",
}

---@class dot.ux.widget
---@field public __mods                 dot.ux.widget.__mods
---@field public Notepad                dot.ux.widget.Notepad
---@field public Terminal               dot.ux.widget.Terminal
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
