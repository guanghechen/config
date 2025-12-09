---@class ux.retriever.__mods
local __mods = {
  ListRetriever = "ux.retriever.list",
  TreeRetriever = "ux.retriever.tree",
}

---@class ux.retriever
---@field public __mods                 ux.retriever.__mods
---
---@field public ListRetriever          ux.retriever.ListRetriever
---@field public TreeRetriever          ux.retriever.TreeRetriever
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
