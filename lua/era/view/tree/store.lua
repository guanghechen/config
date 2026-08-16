---@diagnostic disable-next-line: unused-local
local __module_name__ = "era.view.tree.store" ---@type string

local tree_traversal = require("era.view.tree.traversal")

---@class era.view.tree.store.IView
---@field public statemap               table<string, era.view.tree.INodeState>
---@field protected _tree               stl.c.IReadonlyTree
---@field protected __health__          fun(self: era.view.tree.store.IView): nil

local M = {}

---@param view                          era.view.tree.store.IView
---@param root                          string|nil
---@return string[]
function M.collect_leafs(view, root)
  view:__health__()
  local statemap = view.statemap ---@type table<string, era.view.tree.INodeState>
  local uuids = {} ---@type string[]
  tree_traversal.preorder(view._tree, root, function(uuid)
    local state = statemap[uuid] ---@type era.view.tree.INodeState|nil
    if state ~= nil and state.nodetype == "leaf" then
      uuids[#uuids + 1] = uuid
    end
  end)
  return uuids
end

---@param view                          era.view.tree.store.IView
---@param uuid                          string
---@param state                         era.view.tree.INodeState
---@return era.view.tree.store.IView
function M.insert(view, uuid, state)
  view:__health__()
  local statemap = view.statemap ---@type table<string, era.view.tree.INodeState>
  local oldstate = statemap[uuid] ---@type era.view.tree.INodeState|nil
  if oldstate ~= nil and oldstate.locations ~= nil then
    for _, location in ipairs(oldstate.locations) do
      statemap[location.locationuuid] = nil
    end
  end

  statemap[uuid] = state
  if state.locations ~= nil then
    for _, location in ipairs(state.locations) do
      statemap[location.locationuuid] = location
    end
  end
  return view
end

---@param view                          era.view.tree.store.IView
---@param uuid                          string
---@return era.view.tree.store.IView
function M.remove(view, uuid)
  view:__health__()
  local statemap = view.statemap ---@type table<string, era.view.tree.INodeState>
  tree_traversal.preorder(view._tree, uuid, function(nodeuuid)
    local state = statemap[nodeuuid] ---@type era.view.tree.INodeState|nil
    if state ~= nil then
      statemap[nodeuuid] = nil
      if state.locations ~= nil then
        for _, location in ipairs(state.locations) do
          statemap[location.locationuuid] = nil
        end
      end
    end
  end)
  return view
end

---@param view                          era.view.tree.store.IView
---@param leafstate                     era.view.tree.ILeafNodeState
---@return nil
function M.remove_all_locations(view, leafstate)
  view:__health__()
  if leafstate.locations ~= nil then
    for _, location in ipairs(leafstate.locations) do
      view.statemap[location.locationuuid] = nil
    end
    leafstate.locations = nil
  end
end

---@param view                          era.view.tree.store.IView
---@param leafstate                     era.view.tree.ILeafNodeState
---@param locationuuid                  string
---@return nil
function M.remove_location(view, leafstate, locationuuid)
  view:__health__()
  if leafstate.locations == nil then
    return
  end

  local locations = leafstate.locations ---@type era.view.tree.ILeafLocationState[]
  local count = 0 ---@type integer
  for _, location in ipairs(locations) do
    if location.locationuuid == locationuuid then
      view.statemap[location.locationuuid] = nil
    else
      count = count + 1
      locations[count] = location
    end
  end
  stl.table.truncate_inline(locations, count)
end

---@param view                          era.view.tree.store.IView
---@param uuid                          string
---@return era.view.tree.INodeState|nil
function M.retrieve(view, uuid)
  view:__health__()
  return view.statemap[uuid]
end

return M
