---@diagnostic disable-next-line: unused-local
local __module_name__ = "era.keystroke" ---@type string

---@class era.keystroke.__mods
local __mods = {
  splitjoin = "era.keystroke.splitjoin",
  surrounds = "era.keystroke.surrounds",
}

---@class era.keystroke
---@field public __mods                 era.keystroke.__mods
---@field public splitjoin              era.keystroke.splitjoin
---@field public surrounds              era.keystroke.surrounds
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
