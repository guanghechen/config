---@class eve.ux.widget.ai.__mods
local __mods = {
  action = "eve.ux.widget.ai.action",
  config = "eve.ux.widget.ai.config",
  picker = "eve.ux.widget.ai.picker",
  proc = "eve.ux.widget.ai.proc",
  prompt = "eve.ux.widget.ai.prompt",
  state = "eve.ux.widget.ai.state",
  term = "eve.ux.widget.ai.term",
  tmux = "eve.ux.widget.ai.tmux",
}

---@class eve.ux.widget.ai
---@field public action                 eve.ux.widget.ai.action
---@field public config                 eve.ux.widget.ai.config
---@field public picker                 eve.ux.widget.ai.picker
---@field public proc                   eve.ux.widget.ai.proc
---@field public prompt                 eve.ux.widget.ai.prompt
---@field public state                  eve.ux.widget.ai.state
---@field public term                   eve.ux.widget.ai.term
---@field public tmux                   eve.ux.widget.ai.tmux
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
