---@class dot.widget.__mods
local __mods = {
  Notepad = "dot.widget.notepad",
  Terminal = "dot.widget.terminal",
}

---@class dot.widget
---@field public __mods                 dot.widget.__mods
---@field public Notepad                dot.widget.Notepad
---@field public Terminal               dot.widget.Terminal
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
