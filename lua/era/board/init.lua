---@class era.board.__mods
local __mods = {
  Act = "era.board.act",
  Fileinfo = "era.board.fileinfo",
  GitHunk = "era.board.git-hunk",
}

---@class era.board
---@field public __mods                 era.board.__mods
---@field public Act                    era.board.Act
---@field public Fileinfo               era.board.Fileinfo
---@field public GitHunk                era.board.GitHunk
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
