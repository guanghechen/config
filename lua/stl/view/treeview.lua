---@diagnostic disable-next-line: unused-local
local __module_name__ = "stl.view.treeview" ---@type string

---@class stl.view.treeview
---@field public layout fun(props: stl.view.treeview.ILayoutProps): stl.view.TreeLayout
local M = {
  layout = require("stl.view.treeview.layout").layout,
}

return M
