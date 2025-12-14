---@class dot.ux.widget.ai.__mods
local __mods = {
  action = "dot.ux.widget.ai.action",
  config = "dot.ux.widget.ai.config",
  picker = "dot.ux.widget.ai.picker",
  proc = "dot.ux.widget.ai.proc",
  prompt = "dot.ux.widget.ai.prompt",
  state = "dot.ux.widget.ai.state",
  term = "dot.ux.widget.ai.term",
  tmux = "dot.ux.widget.ai.tmux",
}

---@class dot.ux.widget.ai
---@field public action                 dot.ux.widget.ai.action
---@field public config                 dot.ux.widget.ai.config
---@field public picker                 dot.ux.widget.ai.picker
---@field public proc                   dot.ux.widget.ai.proc
---@field public prompt                 dot.ux.widget.ai.prompt
---@field public state                  dot.ux.widget.ai.state
---@field public term                   dot.ux.widget.ai.term
---@field public tmux                   dot.ux.widget.ai.tmux
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
