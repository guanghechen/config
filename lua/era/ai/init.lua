---@class era.ai.__mods
local __mods = {
  action = "era.ai.action",
  config = "era.ai.config",
  picker = "era.ai.picker",
  proc = "era.ai.proc",
  prompt = "era.ai.prompt",
  state = "era.ai.state",
  term = "era.ai.term",
  tmux = "era.ai.tmux",
}

---@class era.ai
---@field public __mods                 era.ai.__mods
---@field public action                 era.ai.action
---@field public config                 era.ai.config
---@field public picker                 era.ai.picker
---@field public proc                   era.ai.proc
---@field public prompt                 era.ai.prompt
---@field public state                  era.ai.state
---@field public term                   era.ai.term
---@field public tmux                   era.ai.tmux
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
