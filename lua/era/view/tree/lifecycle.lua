---@diagnostic disable-next-line: unused-local
local __module_name__ = "era.view.tree.lifecycle" ---@type string

local M = {}

---@param props                         era.view.ITreeProps
---@param owner_name                    string
---@return era.view.Tree
function M.create(props, owner_name)
  local name = props.name ---@type string
  local self = {
    fullname = props.fullname or string.format("%s -> %s", name, owner_name),
    statemap = {},
    _disposed = false,
    _indent = props.indent or "",
    _indent_hln = props.indent_hln or "f_utw_indent",
    _tree = props.tree,
    _dirty_selected = false,
    _tick_invisible = 1,
    _tick_matched = 0,
    _tick_selected = 1,
    _tick_render_listview = 0,
    _tick_render_treeview = 0,
    _render_listview_leaf = props.render_listview_leaf,
    _render_listview_location = props.render_listview_location,
    _render_treeview_container = props.render_treeview_container,
    _render_treeview_leaf = props.render_treeview_leaf,
    _render_treeview_location = props.render_treeview_location,
  } ---@type era.view.Tree
  return self
end

---@param view                          era.view.Tree
---@return era.view.Tree
function M.clear(view)
  view:__health__()
  table.clear(view.statemap)
  view._dirty_selected = false
  view._tick_invisible = view._tick_invisible + 1
  view._tick_matched = view._tick_matched + 1
  view._tick_selected = view._tick_selected + 1
  view._tick_render_listview = view._tick_render_listview + 1
  view._tick_render_treeview = view._tick_render_treeview + 1
  return view
end

---@param view                          era.view.Tree
---@return nil
function M.dispose(view)
  if view._disposed then
    return
  end
  view._disposed = true

  view.statemap = nil
  view._indent = nil
  view._indent_hln = nil
  view._tree = nil
  view._dirty_selected = nil
  view._tick_invisible = nil
  view._tick_matched = nil
  view._tick_selected = nil
  view._tick_render_listview = nil
  view._tick_render_treeview = nil
  view._render_listview_leaf = nil
  view._render_listview_location = nil
  view._render_treeview_container = nil
  view._render_treeview_leaf = nil
  view._render_treeview_location = nil
end

---@param view                          era.view.Tree
---@return boolean
function M.isdisposed(view)
  return view._disposed
end

---@param view                          era.view.Tree
---@return nil
function M.health(view)
  if view._disposed then
    error(string.format("[%s] has been disposed.", view.fullname))
  end
end

return M
