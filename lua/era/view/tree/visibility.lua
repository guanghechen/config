---@diagnostic disable-next-line: unused-local
local __module_name__ = "era.view.tree.visibility" ---@type string

---@class era.view.tree.visibility.IView
---@field public statemap               table<string, era.view.tree.INodeState>
---@field protected _tick_invisible     integer
---@field protected __health__          fun(self: era.view.tree.visibility.IView): nil

local M = {}

---@param view                          era.view.tree.visibility.IView
---@param uuid                          string
---@return boolean
function M.isvisible(view, uuid)
  local nodestate = view.statemap ~= nil and view.statemap[uuid] or nil ---@type era.view.tree.INodeState|nil
  return nodestate ~= nil and nodestate.tick_invisible ~= view._tick_invisible
end

---@param view                          era.view.tree.visibility.IView
---@param nodeuuid                      string
---@return era.view.tree.visibility.IView
function M.mark_node_invisible(view, nodeuuid)
  view:__health__()
  local nodestate = view.statemap[nodeuuid] ---@type era.view.tree.INodeState|nil
  if nodestate ~= nil then
    nodestate.tick_invisible = view._tick_invisible ---@type integer
  end
  return view
end

---@param view                          era.view.tree.visibility.IView
---@return era.view.tree.visibility.IView
function M.mark_cache_invisible_dirty(view)
  view:__health__()
  view._tick_invisible = view._tick_invisible + 1
  return view
end

return M
