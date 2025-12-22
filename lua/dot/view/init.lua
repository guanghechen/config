---@class dot.view.IView
---@field public fullname               string
---@field public nsnr                   integer
---@field public clear                  fun(self: dot.view.IView): dot.view.IView
---@field public dispose                fun(self: dot.view.IView): nil
---@field public isdisposed             fun(self: dot.view.IView): boolean
---@field public render                 fun(self: dot.view.IView, bufnr: integer, force: boolean): dot.view.IView

---@class dot.view.__mods
local __mods = {
  Plainfile = "dot.view.plainfile",
  Printer = "dot.view.printer",
  Tree = "dot.view.tree",
}

---@class dot.view
---@field public __mods                 dot.view.__mods
---
---@field public Plainfile              dot.view.Plainfile
---@field public Printer                dot.view.Printer
---@field public Tree                   dot.view.Tree
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
