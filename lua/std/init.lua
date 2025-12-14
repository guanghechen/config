---@class std.__mods
local __mods = {
  Filetree = "std.collection.filetree",
}

---@class std
---@field public __mods                 std.__mods
---@field public Filetree               std.collection.Filetree
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
