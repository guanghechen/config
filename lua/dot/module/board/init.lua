---@class dot.module.board.__mods
local __mods = {
  Fileinfo = "dot.module.board.fileinfo",
  GitHunk = "dot.module.board.git-hunk",
  Keysheet = "dot.module.board.keysheet",
}

---@class dot.module.board
---@field public __mods                 dot.module.board.__mods
---@field public Fileinfo               dot.module.board.Fileinfo
---@field public GitHunk                dot.module.board.GitHunk
---@field public Keysheet               dot.module.board.Keysheet
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
