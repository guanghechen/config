---@class eve.ux.retriever.__mods
local __mods = {
  ListRetriever = "eve.ux.retriever.list",
  TreeRetriever = "eve.ux.retriever.tree",
}

---@class eve.ux.retriever
---@field public __mods                 eve.ux.retriever.__mods
---
---@field public ListRetriever          eve.ux.retriever.ListRetriever
---@field public TreeRetriever          eve.ux.retriever.TreeRetriever
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
