---@class ux.widget.ai.__mods
local __mods = {
  action = "ux.widget.ai.action",
  config = "ux.widget.ai.config",
  picker = "ux.widget.ai.picker",
  proc = "ux.widget.ai.proc",
  prompt = "ux.widget.ai.prompt",
  state = "ux.widget.ai.state",
  term = "ux.widget.ai.term",
  tmux = "ux.widget.ai.tmux",
}

---@class ux.widget.ai
---@field public action                 ux.widget.ai.action
---@field public config                 ux.widget.ai.config
---@field public picker                 ux.widget.ai.picker
---@field public proc                   ux.widget.ai.proc
---@field public prompt                 ux.widget.ai.prompt
---@field public state                  ux.widget.ai.state
---@field public term                   ux.widget.ai.term
---@field public tmux                   ux.widget.ai.tmux
local M = setmetatable({}, {
  __index = function(t, k)
    local m = __mods[k] ---@type string|nil
    if m == nil then
      return rawget(t, k)
    end
    return require(m)
  end,
})

return M
