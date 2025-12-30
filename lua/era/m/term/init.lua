---@class era.m.term.__mods
local __mods = {
  action = "era.m.term.action",
  event = "era.m.term.event",
  state = "era.m.term.state",
  widget = "era.m.term.widget",
}

---@class era.m.term
---@field public __mods                 era.m.term.__mods
---@field public action                 era.m.term.action
---@field public event                  era.m.term.event
---@field public state                  era.m.term.state
---@field public widget                 era.m.term.widget
local M = setmetatable({
  __mods = __mods,
}, {
  __index = function(_, k)
    local m = __mods[k] ---@type string|nil
    if m ~= nil then
      return require(m)
    end
  end,
})

return M
