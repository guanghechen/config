---@class era.view.__mods
local __mods = {
  Plainfile = "era.view.plainfile",
  Printer = "era.view.printer",
  Tree = "era.view.tree",
}

---@class era.view
---@field public __mods                 era.view.__mods
---@field public Plainfile              era.view.Plainfile
---@field public Printer                era.view.Printer
---@field public Tree                   era.view.Tree
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
