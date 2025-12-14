---@class dot.ux.retriever.__mods
local __mods = {
  ListRetriever = "dot.ux.retriever.list",
  TreeRetriever = "dot.ux.retriever.tree",
}

---@class dot.ux.retriever
---@field public __mods                 dot.ux.retriever.__mods
---
---@field public ListRetriever          dot.ux.retriever.ListRetriever
---@field public TreeRetriever          dot.ux.retriever.TreeRetriever
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
