---@diagnostic disable-next-line: unused-local
local __module_name__ = "era.keystroke" ---@type string

---@class era.keystroke.__mods
local __mods = {
  colorpicker = "era.keystroke.colorpicker",
  splitjoin = "era.keystroke.splitjoin",
  splitline = "era.keystroke.splitline",
  surrounds = "era.keystroke.surrounds",
  textobject = "era.keystroke.textobject",
}

---@class era.keystroke
---@field public __mods                 era.keystroke.__mods
---@field public colorpicker            era.keystroke.colorpicker
---@field public splitjoin              era.keystroke.splitjoin
---@field public splitline              era.keystroke.splitline
---@field public surrounds              era.keystroke.surrounds
---@field public textobject             era.keystroke.textobject
local M = setmetatable({
  __mods = __mods,
}, {
  __index = function(t, k)
    local mod = __mods[k] ---@type string|nil
    if mod == nil then
      return rawget(t, k)
    end
    return require(mod)
  end,
})

return M
