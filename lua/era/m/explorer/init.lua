---@diagnostic disable-next-line: unused-local
local __module_name__ = "era.m.explorer" ---@type string

---@class era.m.explorer.__mods
local __mods = {
  Action = "era.m.explorer.action",
  Session = "era.m.explorer.session",
  View = "era.m.explorer.view",
  Widget = "era.m.explorer.widget",
}

---@class era.m.explorer
---@field public __mods                 era.m.explorer.__mods
---@field public Action                 era.m.explorer.Action
---@field public Session                era.m.explorer.Session
---@field public View                   table
---@field public Widget                 era.m.explorer.Widget
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
