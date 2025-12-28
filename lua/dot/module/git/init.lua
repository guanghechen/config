---@class dot.module.git.__mods
local __mods = {
  blame = "dot.module.git.blame",
  browse = "dot.module.git.browse",
  buffer = "dot.module.git.buffer",
  cmd = "dot.module.git.cmd",
  diff = "dot.module.git.diff",
  hunk = "dot.module.git.hunk",
  repo = "dot.module.git.repo",
  sign = "dot.module.git.sign",
  state = "dot.module.git.state",
  status = "dot.module.git.status",
  watcher = "dot.module.git.watcher",
}

---@class dot.module.git
---@field public __mods                 dot.module.git.__mods
---@field public blame                  dot.module.git.blame
---@field public browse                 dot.module.git.browse
---@field public buffer                 dot.module.git.buffer
---@field public cmd                    dot.module.git.cmd
---@field public diff                   dot.module.git.diff
---@field public hunk                   dot.module.git.hunk
---@field public repo                   dot.module.git.repo
---@field public sign                   dot.module.git.sign
---@field public state                  dot.module.git.state
---@field public status                 dot.module.git.status
---@field public watcher                dot.module.git.watcher
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

-- Setup immediately when module is loaded (called from integration/neovim/init.lua)
M.buffer.setup()
M.blame.setup()
M.watcher.setup()

return M
