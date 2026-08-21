---@see https://github.com/lewis6991/gitsigns.nvim/blob/bf77caa5da671f5bab16e4792711d5aa288e8db0

---@class era.m.git.__mods
local __mods = {
  blame = "era.m.git.blame",
  buffer = "era.m.git.buffer",
  diff = "era.m.git.diff",
  hunk = "era.m.git.hunk",
  hunk_nav = "era.m.git.hunk_nav",
  Hunkview = "era.m.git.hunkview",
  repo = "era.m.git.repo",
  sign = "era.m.git.sign",
  staging = "era.m.git.staging",
  state = "era.m.git.state",
  status = "era.m.git.status",
  watcher = "era.m.git.watcher",
}

---@class era.m.git
---@field public __mods                 era.m.git.__mods
---@field public blame                  era.m.git.blame
---@field public buffer                 era.m.git.buffer
---@field public diff                   era.m.git.diff
---@field public hunk                   era.m.git.hunk
---@field public hunk_nav               era.m.git.hunk_nav
---@field public Hunkview               era.m.git.Hunkview
---@field public repo                   era.m.git.repo
---@field public sign                   era.m.git.sign
---@field public staging                era.m.git.staging
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

---@return nil
function M.setup()
  M.buffer.setup()
  M.blame.setup()
  M.watcher.setup()
end

return M
