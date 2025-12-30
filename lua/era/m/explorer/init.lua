---@class era.m.explorer.__mods
local __mods = {
  Action = "era.m.explorer.action",
  Node = "era.m.explorer.node",
  Tree = "era.m.explorer.tree",
  View = "era.m.explorer.view",
  Widget = "era.m.explorer.widget",
}

---@class era.m.explorer
---@field public __mods                 era.m.explorer.__mods
---@field public Action                 era.m.explorer.Action
---@field public Node                   era.m.explorer.Node
---@field public Tree                   era.m.explorer.Tree
---@field public View                   era.m.explorer.View
---@field public Widget                 era.m.explorer.Widget
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
