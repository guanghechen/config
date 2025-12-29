---@class era.explorer.__mods
local __mods = {
  Action = "era.explorer.action",
  Node = "era.explorer.node",
  Tree = "era.explorer.tree",
  View = "era.explorer.view",
  Widget = "era.explorer.widget",
}

---@class era.explorer
---@field public __mods                 era.explorer.__mods
---@field public Action                 era.explorer.Action
---@field public Node                   era.explorer.Node
---@field public Tree                   era.explorer.Tree
---@field public View                   era.explorer.View
---@field public Widget                 era.explorer.Widget
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
