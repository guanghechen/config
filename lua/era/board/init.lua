---@class era.board.__mods
local __mods = {
  Act = "era.board.act",
}

---@class era.board
---@field public __mods                 era.board.__mods
---@field public Act                    era.board.Act
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
