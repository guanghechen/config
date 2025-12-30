---@class era.m.ai.__mods
local __mods = {
  action = "era.m.ai.action",
  config = "era.m.ai.config",
  picker = "era.m.ai.picker",
  proc = "era.m.ai.proc",
  prompt = "era.m.ai.prompt",
  state = "era.m.ai.state",
  term = "era.m.ai.term",
  tmux = "era.m.ai.tmux",
}

---@class era.m.ai
---@field public __mods                 era.m.ai.__mods
---@field public action                 era.m.ai.action
---@field public config                 era.m.ai.config
---@field public picker                 era.m.ai.picker
---@field public proc                   era.m.ai.proc
---@field public prompt                 era.m.ai.prompt
---@field public state                  era.m.ai.state
---@field public term                   era.m.ai.term
---@field public tmux                   era.m.ai.tmux
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
