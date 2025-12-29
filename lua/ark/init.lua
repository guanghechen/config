---@class ark.view.IView
---@field public fullname               string
---@field public nsnr                   integer
---@field public clear                  fun(self: ark.view.IView): ark.view.IView
---@field public dispose                fun(self: ark.view.IView): nil
---@field public isdisposed             fun(self: ark.view.IView): boolean
---@field public render                 fun(self: ark.view.IView, bufnr: integer, force: boolean): ark.view.IView

---@class ark.view.__mods
local view__mods = {
  Plainfile = "ark.view.plainfile",
  Printer = "ark.view.printer",
  Tree = "ark.view.tree",
}

---@class ark.view
---@field public __mods                 ark.view.__mods
---@field public Plainfile              ark.view.Plainfile
---@field public Printer                ark.view.Printer
---@field public Tree                   ark.view.Tree
local view = setmetatable({ __mods = view__mods }, {
  __index = function(t, k)
    local m = view__mods[k] ---@type string|nil
    if m == nil then
      return rawget(t, k)
    end
    return require(m)
  end,
})

----------------------------------------------------------------------------------------------------

---@class ark.__mods
local __mods = {}

---@class ark
---@field public __mods                 ark.__mods
---@field public view                   ark.view
local M = setmetatable({
  __mods = __mods,
  view = view,
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
