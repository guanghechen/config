---@see https://github.com/lewis6991/gitsigns.nvim/blob/bf77caa5da671f5bab16e4792711d5aa288e8db0

---@class era.m.git.__mods
local __mods = {
  blame = "era.m.git.blame",
  browse = "era.m.git.browse",
  buffer = "era.m.git.buffer",
  cmd = "era.m.git.cmd",
  diff = "era.m.git.diff",
  hunk = "era.m.git.hunk",
  Hunkview = "era.m.git.hunkview",
  repo = "era.m.git.repo",
  sign = "era.m.git.sign",
  state = "era.m.git.state",
  status = "era.m.git.status",
  watcher = "era.m.git.watcher",
}

---@class era.m.git
---@field public __mods                 era.m.git.__mods
---@field public blame                  era.m.git.blame
---@field public browse                 era.m.git.browse
---@field public buffer                 era.m.git.buffer
---@field public cmd                    era.m.git.cmd
---@field public diff                   era.m.git.diff
---@field public hunk                   era.m.git.hunk
---@field public Hunkview               era.m.git.Hunkview
---@field public repo                   era.m.git.repo
---@field public sign                   era.m.git.sign
---@field public state                  era.m.git.state
---@field public status                 era.m.git.status
---@field public watcher                era.m.git.watcher
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
