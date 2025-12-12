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

---@class era.__mods
local __mods = {
  buf = "era.buf",
  command = "era.command",
  fs = "era.fs",
  git = "era.git",
  path = "era.path",
  session = "era.session",
  tab = "era.tab",
  uri = "era.uri",
  win = "era.win",
}

---@class era
---@field public __mods                 era.__mods
---@field public buf                    era.buf
---@field public command                era.command
---@field public fs                     era.fs
---@field public git                    era.git
---@field public path                   era.path
---@field public session                era.session
---@field public state                  era.state
---@field public tab                    era.tab
---@field public uri                    era.uri
---@field public win                    era.win
local M = setmetatable({
  __mods = __mods,
  state = state,
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
