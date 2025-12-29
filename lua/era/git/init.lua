---@see https://github.com/lewis6991/gitsigns.nvim/blob/bf77caa5da671f5bab16e4792711d5aa288e8db0

---@class era.git.__mods
local __mods = {
  blame = "era.git.blame",
  browse = "era.git.browse",
  buffer = "era.git.buffer",
  cmd = "era.git.cmd",
  diff = "era.git.diff",
  hunk = "era.git.hunk",
  Hunkview = "era.git.hunkview",
  repo = "era.git.repo",
  sign = "era.git.sign",
  state = "era.git.state",
  status = "era.git.status",
  watcher = "era.git.watcher",
}

---@class era.git
---@field public __mods                 era.git.__mods
---@field public blame                  era.git.blame
---@field public browse                 era.git.browse
---@field public buffer                 era.git.buffer
---@field public cmd                    era.git.cmd
---@field public diff                   era.git.diff
---@field public hunk                   era.git.hunk
---@field public Hunkview               era.git.Hunkview
---@field public repo                   era.git.repo
---@field public sign                   era.git.sign
---@field public state                  era.git.state
---@field public status                 era.git.status
---@field public watcher                era.git.watcher
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
