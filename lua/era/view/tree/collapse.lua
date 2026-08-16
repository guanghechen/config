---@diagnostic disable-next-line: unused-local
local __module_name__ = "era.view.tree.collapse" ---@type string

local tree_traversal = require("era.view.tree.traversal")

---@class era.view.tree.collapse.IView
---@field public fullname               string
---@field public statemap               table<string, era.view.tree.INodeState>
---@field protected _tree               stl.c.IReadonlyTree
---@field protected __health__          fun(self: era.view.tree.collapse.IView): nil

local M = {}

---@param view                          era.view.tree.collapse.IView
---@param uuid                          string
---@param value                         era.view.tree.CollapseActionEnum
---@param recursive                     boolean|nil
---@return era.view.tree.collapse.IView
function M.collapse(view, uuid, value, recursive)
  view:__health__()

  local tree = view._tree ---@type stl.c.IReadonlyTree
  if not tree:contains(uuid) then
    stl.reporter.error({
      from = view.fullname,
      subject = "collapse",
      message = "The node isn't exist",
      details = { uuid = uuid, value = value, recursive = recursive },
    })
    return view
  end

  local statemap = view.statemap ---@type table<string, era.view.tree.INodeState>
  local state = statemap[uuid] ---@type era.view.tree.INodeState|nil
  if state == nil then
    stl.reporter.error({
      from = view.fullname,
      subject = "collapse",
      message = "The node state isn't exist",
      details = { uuid = uuid, value = value, recursive = recursive },
    })
    return view
  end

  local collapsed = state.collapsed ---@type boolean
  if value == "toggle" then
    collapsed = not collapsed
  elseif value == "collapse" then
    collapsed = true
  elseif value == "expand" then
    collapsed = false
  end

  if recursive then
    tree_traversal.preorder(tree, uuid, function(nodeuuid)
      local nodestate = statemap[nodeuuid] ---@type era.view.tree.INodeState
      if nodestate.collapsed ~= collapsed then
        nodestate.collapsed = collapsed
        nodestate.cache_listview = nil
        nodestate.cache_treeview = nil
      end
    end)
  elseif state.collapsed ~= collapsed then
    state.collapsed = collapsed
    state.cache_listview = nil
    state.cache_treeview = nil
  end

  return view
end

return M
