---@class eve.ux.view.IView
---@field public name                   string
---@field public nsnr                   integer
---@field public clear                  fun(self: eve.ux.view.IView): eve.ux.view.IView
---@field public dispose                fun(self: eve.ux.view.IView): nil
---@field public isdisposed             fun(self: eve.ux.view.IView): boolean
---@field public render                 fun(self: eve.ux.view.IView, bufnr: integer, force: boolean): eve.ux.view.IView

---@class eve.ux.view.__mods
local __mods = {
  Filetree = "eve.ux.view.filetree",
  Plainfile = "eve.ux.view.plainfile",
  Printer = "eve.ux.view.printer",
  Treeview = "eve.ux.view.treeview",
}

---@class eve.ux.view
---@field public __mods                 eve.ux.view.__mods
---
---@field public Filetree               eve.ux.view.Filetree
---@field public Plainfile              eve.ux.view.Plainfile
---@field public Printer                eve.ux.view.Printer
---@field public Treeview               eve.ux.view.Treeview
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
