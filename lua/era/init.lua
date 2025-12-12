---@class era.state.__mods
local __state__mods = {
  git = "era.state.git",
  maximized = "era.state.maximized",
  notepad = "era.state.notepad",
  qflist = "era.state.qflist",
  status = "era.state.status",
  widget = "era.state.widget",
}

---@class era.state
---@field public __mods                 era.state.__mods
---@field public git                    era.state.git
---@field public maximized              era.state.maximized
---@field public notepad                era.state.notepad
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
  context = "era.context",
  fs = "era.fs",
  git = "era.git",
  notifier = "era.notifier",
  path = "era.path",
  session = "era.session",
  tab = "era.tab",
  term = "era.term",
  uri = "era.uri",
  win = "era.win",
}

---@class era
---@field public __mods                 era.__mods
---@field public buf                    era.buf
---@field public command                era.command
---@field public context                era.context
---@field public fs                     era.fs
---@field public git                    era.git
---@field public notifier               era.notifier
---@field public path                   era.path
---@field public session                era.session
---@field public state                  era.state
---@field public tab                    era.tab
---@field public term                   era.term
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
