---@class dot.module.tree.__mods
local __mods = {
  Tree = "dot.module.tree.tree",
  Filetree = "dot.module.tree.filetree",
}

---@class dot.module.tree
---@field public __mods                 dot.module.tree.__mods
---@field public Tree                   dot.Tree
---@field public Filetree               dot.Filetree
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
