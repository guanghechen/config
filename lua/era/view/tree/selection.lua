---@diagnostic disable-next-line: unused-local
local __module_name__ = "era.view.tree.selection" ---@type string

local tree_traversal = require("era.view.tree.traversal")

local EMPTY_CHILDREN = {} ---@type string[]

---@class era.view.tree.selection.IView
---@field public statemap               table<string, era.view.tree.INodeState>
---@field protected _dirty_selected     boolean
---@field protected _tick_invisible     integer
---@field protected _tick_selected      integer
---@field protected _tree               stl.c.IReadonlyTree
---@field protected __health__          fun(self: era.view.tree.selection.IView): nil

local M = {}

---@param view                          era.view.tree.selection.IView
---@param uuid                          string
---@return boolean
function M.isselected(view, uuid)
  local nodestate = view.statemap ~= nil and view.statemap[uuid] or nil ---@type era.view.tree.INodeState|nil
  return nodestate ~= nil and nodestate.tick_selected == view._tick_selected
end

---@param view                          era.view.tree.selection.IView
---@param root                          string|nil
---@return table<string, true>
function M.collect_selected(view, root)
  view:__health__()

  local statemap = view.statemap ---@type table<string, era.view.tree.INodeState>
  local tick_selected = view._tick_selected ---@type integer
  local selected_set = {} ---@type table<string, true>
  tree_traversal.preorder(view._tree, root, function(uuid)
    local state = statemap[uuid] ---@type era.view.tree.INodeState|nil
    if state ~= nil and state.tick_selected == tick_selected then
      selected_set[uuid] = true
    end
  end)
  return selected_set
end

---@param view                          era.view.tree.selection.IView
---@param nodeuuid                      string
---@param selected                      boolean
---@return era.view.tree.selection.IView
function M.set_selected(view, nodeuuid, selected)
  view:__health__()

  local tick_selected = view._tick_selected ---@type integer
  local nodestate = view.statemap[nodeuuid] ---@type era.view.tree.INodeState|nil
  if nodestate ~= nil then
    if selected then
      if nodestate.tick_selected ~= tick_selected then
        nodestate.tick_selected = tick_selected ---@type integer
      end
    elseif nodestate.tick_selected == tick_selected then
      nodestate.tick_selected = -1 ---@type integer
    end
  end

  view._dirty_selected = true
  return view
end

---@param view                          era.view.tree.selection.IView
---@param uuid                          string
---@param selected                      boolean
---@param only_visible                  boolean|nil
---@return era.view.tree.selection.IView
function M.toggle_select(view, uuid, selected, only_visible)
  view:__health__()

  local statemap = view.statemap ---@type table<string, era.view.tree.INodeState>
  local tree = view._tree ---@type stl.c.IReadonlyTree
  local tick_invisible = only_visible and view._tick_invisible or -1 ---@type integer
  local tick_selected = view._tick_selected ---@type integer

  tree_traversal.preorder(tree, uuid, function(nodeuuid)
    local nodestate = statemap[nodeuuid] ---@type era.view.tree.INodeState|nil
    if nodestate ~= nil and nodestate.tick_invisible ~= tick_invisible then
      if selected and nodestate.tick_selected ~= tick_selected then
        nodestate.tick_selected = tick_selected ---@type integer
      elseif not selected and nodestate.tick_selected == tick_selected then
        nodestate.tick_selected = -1 ---@type integer
      end
    end
  end)

  view._dirty_selected = true ---@type boolean
  return view
end

---@param view                          era.view.tree.selection.IView
---@return nil
function M.refresh_selected_maximum(view)
  if not view._dirty_selected then
    return
  end

  local tree = view._tree ---@type stl.c.IReadonlyTree
  local statemap = view.statemap ---@type table<string, era.view.tree.INodeState>
  local roots = tree:children(tree.root) or EMPTY_CHILDREN ---@type string[]
  local stack_uuids = {} ---@type string[]
  local stack_indexes = {} ---@type integer[]
  local stack_maximums = {} ---@type integer[]

  for _, rootuuid in ipairs(roots) do
    local stack_size = 1 ---@type integer
    local rootstate = statemap[rootuuid] ---@type era.view.tree.INodeState
    stack_uuids[1] = rootuuid
    stack_indexes[1] = 1
    stack_maximums[1] = rootstate.tick_selected

    while stack_size > 0 do
      local current_uuid = stack_uuids[stack_size] ---@type string
      local children = tree:children(current_uuid) or EMPTY_CHILDREN ---@type string[]
      local child_index = stack_indexes[stack_size] ---@type integer
      if child_index <= #children then
        local childuuid = children[child_index] ---@type string
        local childstate = statemap[childuuid] ---@type era.view.tree.INodeState
        stack_indexes[stack_size] = child_index + 1
        stack_size = stack_size + 1
        stack_uuids[stack_size] = childuuid
        stack_indexes[stack_size] = 1
        stack_maximums[stack_size] = childstate.tick_selected
      else
        local maximum = stack_maximums[stack_size] ---@type integer
        statemap[current_uuid].tick_selected_maximum = maximum
        stack_uuids[stack_size] = nil
        stack_indexes[stack_size] = nil
        stack_maximums[stack_size] = nil
        stack_size = stack_size - 1
        if stack_size > 0 and stack_maximums[stack_size] < maximum then
          stack_maximums[stack_size] = maximum
        end
      end
    end
  end
  view._dirty_selected = false ---@type boolean
end

return M
