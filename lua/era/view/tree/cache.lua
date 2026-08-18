---@diagnostic disable: invisible
---@diagnostic disable-next-line: unused-local
local __module_name__ = "era.view.tree.cache" ---@type string

---@class era.view.tree.cache.IView
---@field protected _tick_render_listview integer
---@field protected _tick_render_treeview integer
---@field protected __health__          fun(self: era.view.tree.cache.IView): nil

local M = {}

---@param view                          era.view.tree.cache.IView
---@return era.view.tree.cache.IView
function M.mark_listview_dirty(view)
  view:__health__()
  view._tick_render_listview = view._tick_render_listview + 1
  return view
end

---@param view                          era.view.tree.cache.IView
---@return era.view.tree.cache.IView
function M.mark_treeview_dirty(view)
  view:__health__()
  view._tick_render_treeview = view._tick_render_treeview + 1
  return view
end

return M
