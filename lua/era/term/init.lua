---@class era.term.__mods
local __mods = {
  action = "era.term.action",
  event = "era.term.event",
  state = "era.term.state",
  widget = "era.term.widget",
}

---@class era.term
---@field public __mods                 era.term.__mods
---@field public action                 era.term.action
---@field public event                  era.term.event
---@field public state                  era.term.state
---@field public widget                 era.term.widget
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
