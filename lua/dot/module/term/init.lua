---@class dot.module.term.__mods
local __mods = {
  action = "dot.module.term.action",
  event = "dot.module.term.event",
  state = "dot.module.term.state",
  widget = "dot.module.term.widget",
}

---@class dot.term
---@field public __mods                 dot.module.term.__mods
---@field public action                 dot.module.term.action
---@field public event                  dot.module.term.event
---@field public state                  dot.module.term.state
---@field public widget                 dot.module.term.widget
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
