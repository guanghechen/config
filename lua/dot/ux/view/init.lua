---@class dot.ux.view.IView
---@field public fullname               string
---@field public nsnr                   integer
---@field public clear                  fun(self: dot.ux.view.IView): dot.ux.view.IView
---@field public dispose                fun(self: dot.ux.view.IView): nil
---@field public isdisposed             fun(self: dot.ux.view.IView): boolean
---@field public render                 fun(self: dot.ux.view.IView, bufnr: integer, force: boolean): dot.ux.view.IView

---@class dot.ux.view.__mods
local __mods = {
  Plainfile = "dot.ux.view.plainfile",
  Printer = "dot.ux.view.printer",
  Tree = "dot.ux.view.tree",
}

---@class dot.ux.view
---@field public __mods                 dot.ux.view.__mods
---
---@field public Plainfile              dot.ux.view.Plainfile
---@field public Printer                dot.ux.view.Printer
---@field public Tree                   dot.ux.view.Tree
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
