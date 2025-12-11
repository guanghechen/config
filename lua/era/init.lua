---@class era.state.__mods
local __state__mods = {
  maximized = "era.state.maximized",
  qflist = "era.state.qflist",
  status = "era.state.status",
  widget = "era.state.widget",
}

---@class era.state
---@field public __mods                 era.state.__mods
---@field public maximized              era.state.maximized
---@field public qflist                 era.state.qflist
---@field public status                 era.state.status
---@field public widget                 era.state.widget
local state = setmetatable({
  __mods = __state__mods,
}, {
  __index = function(t, k)
    local m = __state__mods[k] ---@type string|nil
    if m == nil then
      return rawget(t, k)
    end
    return require(m)
  end,
})

----------------------------------------------------------------------------------------------------

---@class era
---@field public state                  era.state
local M = {
  state = state,
}

return M
