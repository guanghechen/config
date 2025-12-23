---@class dot.module.tree.__mods
local __mods = {
  TreeRetriever = "dot.module.tree.retriever",
}

---@class dot.module.tree
---@field public __mods                 dot.module.tree.__mods
---@field public TreeRetriever          dot.module.tree.TreeRetriever
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
