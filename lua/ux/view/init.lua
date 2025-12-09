---@class ux.view.IView
---@field public fullname               string
---@field public nsnr                   integer
---@field public clear                  fun(self: ux.view.IView): ux.view.IView
---@field public dispose                fun(self: ux.view.IView): nil
---@field public isdisposed             fun(self: ux.view.IView): boolean
---@field public render                 fun(self: ux.view.IView, bufnr: integer, force: boolean): ux.view.IView

---@class ux.view.__mods
local __mods = {
  Plainfile = "ux.view.plainfile",
  Printer = "ux.view.printer",
  Tree = "ux.view.tree",
}

---@class ux.view
---@field public __mods                 ux.view.__mods
---
---@field public Plainfile              ux.view.Plainfile
---@field public Printer                ux.view.Printer
---@field public Tree                   ux.view.Tree
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
