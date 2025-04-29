local __module_name__ = "eve.ux.view.treeview" ---@type string

---@alias eve.ux.view.treeview.NodeTypeEnum
---| 'container'
---| 'leaf'

---@alias eve.ux.view.treeview.INode
---| eve.ux.view.treeview.IContainerNode
---| eve.ux.view.treeview.ILeafNode

---@alias eve.ux.view.treeview.INodeRenderer
---| fun(data: unknown, uuid: string, parent_uuid: string, depth: integer): string, eve.t.IHighlightInline[]

---@alias eve.ux.view.treeview.INodeSorter
---| fun(left: unknown, right: unknown): boolean

---@class eve.ux.view.treeview.IContainerNode
---@field public type                   'container'
---@field public uuid                   string
---@field public parent                 string
---@field public depth                  integer
---@field public data                   unknown
---@field public text                   string|nil
---@field public highlights             eve.t.IHighlightInline[]|nil
---@field public collapsed              boolean
---@field public dirty_orders           boolean
---@field public children               string[]

---@class eve.ux.view.treeview.ILeafNode
---@field public type                   'leaf'
---@field public uuid                   string
---@field public parent                 string
---@field public depth                  integer
---@field public data                   unknown
---@field public text                   string|nil
---@field public highlights             eve.t.IHighlightInline[]|nil

---@class eve.ux.view.ITreeviewProps
---@field public name                   string
---@field public nsnr                   ?integer
---@field public renderer               eve.ux.view.treeview.INodeRenderer
---@field public sorter                 eve.ux.view.treeview.INodeSorter

---@class eve.ux.view.Treeview : eve.ux.view.IView
---@field protected _disposed           boolean
---@field protected _node_map           table<string, eve.ux.view.treeview.INode>
---@field protected _node_root          eve.ux.view.treeview.IContainerNode
---@field protected _renderer           eve.ux.view.treeview.INodeRenderer
---@field protected _sorter             eve.ux.view.treeview.INodeSorter
local M = {}
M.__index = M

local NSNR_DEFAULT = vim.api.nvim_create_namespace("ux_view_treeview") ---@type integer

---@param props                         eve.ux.view.ITreeviewProps
---@return eve.ux.view.Treeview
function M.new(props)
  local name = props.name ---@type string
  local nsnr = props.nsnr or NSNR_DEFAULT ---@type integer
  local renderer = props.renderer ---@type eve.ux.view.treeview.INodeRenderer
  local sorter = props.sorter ---@type eve.ux.view.treeview.INodeSorter

  local self = setmetatable({}, M)

  ---@type eve.ux.view.treeview.IContainerNode
  local root = {
    type = "container",
    parent = "__virtual_root__",
    uuid = "__virtual_root__",
    depth = 0,
    data = nil,
    collapsed = false,
    dirty_orders = false,
    children = {},
  }

  self.name = name
  self.nsnr = nsnr
  self._disposed = false
  self._node_map = {}
  self._node_root = root
  self._renderer = renderer
  self._sorter = sorter
  return self
end

---@return eve.ux.view.Treeview
function M:clear()
  self:health()

  self._node_map = {}
  self._node_root.children = {}
  self._node_root.dirty_orders = false
  return self
end

---@return nil
function M:dispose()
  if self._disposed then
    return nil
  end

  self._disposed = true
  self._node_map = nil
  self._node_root = nil
  self._renderer = nil
  self._sorter = nil
end

---@return boolean
function M:isdisposed()
  return self._disposed
end

---@return nil
function M:health()
  if self._disposed then
    local message = string.format("Treeview (%s) has been disposed.", self.name) ---@type string
    error(message)
  end
end

----------------------------------------------------------------------------------------------------

---@param uuid                          string
---@param value                         "collapsed"|"expanded"|"toggle"
---@param recursive                     ?boolean
---@return eve.ux.view.Treeview
function M:collapse(uuid, value, recursive)
  self:health()

  local node = self._node_map[uuid] ---@type eve.ux.view.treeview.INode|nil
  if node == nil then
    eve.reporter.error({
      from = __module_name__,
      subject = "collapse",
      message = "The node isn't exist",
      details = { uuid = uuid, value = value, recursive = recursive },
    })
    return self
  end

  if node.type ~= "container" then
    eve.reporter.warn({
      from = __module_name__,
      subject = "collapse (ignored)",
      message = "The node is not a container node",
      details = { uuid = uuid, value = value, recursive = recursive },
    })
    return self
  end

  local collapsed = node.collapsed ---@type boolean
  if value == "toggle" then
    collapsed = not collapsed
  elseif value == "collapsed" then
    collapsed = true
  elseif value == "expanded" then
    collapsed = false
  end

  node.collapsed = collapsed
  if recursive then
    self:update_collapse_recursively(node, collapsed)
  end
  return self
end

---@param uuid                          string
---@param parent_uuid                   string
---@param data                          unknown
---@param collapsed                     ?boolean
---@return eve.ux.view.Treeview
function M:insert_container(uuid, parent_uuid, data, collapsed)
  self:health()

  local node_map = self._node_map ---@type table<string, eve.ux.view.treeview.INode>

  local node = node_map[uuid] ---@type eve.ux.view.treeview.INode|nil
  if node ~= nil then
    return self:update_container(uuid, parent_uuid, data, collapsed)
  end

  local parent = self:retrieve_parent(uuid, parent_uuid) ---@type eve.ux.view.treeview.IContainerNode|nil
  if parent == nil then
    return self
  end

  ---@type eve.ux.view.treeview.IContainerNode
  local new_node = {
    type = "container",
    uuid = uuid,
    parent = parent_uuid,
    depth = parent.depth + 1,
    data = data,
    collapsed = collapsed == true,
    dirty_orders = false,
    children = {},
  }

  parent.children[#parent.children + 1] = uuid
  parent.dirty_orders = true
  node_map[uuid] = new_node
  return self
end

---@param uuid                          string
---@param parent_uuid                   string
---@param data                          unknown
---@return eve.ux.view.Treeview
function M:insert_leaf(uuid, parent_uuid, data)
  self:health()

  local node_map = self._node_map ---@type table<string, eve.ux.view.treeview.INode>

  local old_node = node_map[uuid] ---@type eve.ux.view.treeview.INode|nil
  if old_node ~= nil then
    return self:update_leaf(uuid, parent_uuid, data)
  end

  local parent = self:retrieve_parent(uuid, parent_uuid) ---@type eve.ux.view.treeview.IContainerNode|nil
  if parent == nil then
    return self
  end

  ---@type eve.ux.view.treeview.ILeafNode
  local new_node = {
    type = "leaf",
    uuid = uuid,
    parent = parent_uuid,
    depth = parent.depth + 1,
    data = data,
  }

  parent.children[#parent.children + 1] = uuid
  parent.dirty_orders = true
  node_map[uuid] = new_node
  return self
end

---@param uuid                          string
---@return eve.ux.view.Treeview
function M:remove(uuid)
  self:health()

  local node_map = self._node_map ---@type table<string, eve.ux.view.treeview.INode>
  local node = node_map[uuid] ---@type eve.ux.view.treeview.INode|nil

  if node == nil then
    eve.reporter.error({
      from = __module_name__,
      subject = "remove",
      message = "The node isn't exist",
      details = { uuid = uuid },
    })
    return self
  end

  local parent = self:retrieve_parent(uuid, node.parent) ---@type eve.ux.view.treeview.IContainerNode|nil
  if parent == nil then
    return self
  end

  parent.children = vim.tbl_filter(function(child_uuid)
    return child_uuid ~= uuid
  end, parent.children)

  node_map[uuid] = nil
  if node.type == "container" then
    self:remove_recursively(node)
  end

  return self
end

---@param uuid                          string
---@param parent_uuid                   string|nil
---@param data                          unknown
---@param collapsed                     ?boolean
---@param insert_if_non_exist           ?boolean
---@return eve.ux.view.Treeview
function M:update_container(uuid, parent_uuid, data, collapsed, insert_if_non_exist)
  self:health()

  local node_map = self._node_map ---@type table<string, eve.ux.view.treeview.INode>

  local node = node_map[uuid] ---@type eve.ux.view.treeview.INode|nil
  if node == nil then
    if not insert_if_non_exist then
      eve.reporter.error({
        from = __module_name__,
        subject = "update_container (ignored)",
        message = "The node isn't exist",
        details = { uuid = uuid, parent_uuid = parent_uuid, data = data, collapsed = collapsed },
      })
      return self
    end

    if parent_uuid == nil then
      eve.reporter.error({
        from = __module_name__,
        subject = "update_container (ignored)",
        message = "The node isn't exist and the parent_uuid not provided",
        details = { uuid = uuid, parent_uuid = parent_uuid, data = data, collapsed = collapsed },
      })
      return self
    end

    return self:insert_container(uuid, parent_uuid, data, collapsed)
  end

  if node.type ~= "container" then
    eve.reporter.warn({
      from = __module_name__,
      subject = "update_container (ignored)",
      message = "The exists node is not a container node",
      details = { uuid = uuid, parent_uuid = parent_uuid, data = data, collapsed = collapsed, old_node = node },
    })
    return self
  end

  parent_uuid = parent_uuid or node.parent ---@type string
  if node.parent == parent_uuid then
    node.data = data
    if collapsed ~= nil then
      node.collapsed = collapsed ---@type boolean
    end
    return self
  end

  local old_parent_node = self:retrieve_parent(uuid, node.parent) ---@type eve.ux.view.treeview.IContainerNode|nil
  if old_parent_node == nil then
    return self
  end

  local parent = self:retrieve_parent(uuid, parent_uuid) ---@type eve.ux.view.treeview.IContainerNode|nil
  if parent == nil then
    return self
  end

  old_parent_node.children = vim.tbl_filter(function(child_uuid)
    return child_uuid ~= uuid
  end, old_parent_node.children)

  if collapsed ~= nil then
    node.collapsed = collapsed ---@type boolean
  end
  if node.depth ~= parent.depth + 1 then
    node.depth = parent.depth + 1
    self:update_depth_recursively(node)
  end

  node.data = data
  node.parent = parent_uuid
  parent.children[#parent.children + 1] = uuid
  parent.dirty_orders = true
  return self
end

---@param uuid                          string
---@param parent_uuid                   string|nil
---@param data                          unknown
---@param insert_if_non_exist           boolean|nil
---@return eve.ux.view.Treeview
function M:update_leaf(uuid, parent_uuid, data, insert_if_non_exist)
  self:health()

  local node_map = self._node_map ---@type table<string, eve.ux.view.treeview.INode>

  local node = node_map[uuid] ---@type eve.ux.view.treeview.INode|nil
  if node == nil then
    if not insert_if_non_exist then
      eve.reporter.error({
        from = __module_name__,
        subject = "update_leaf (ignored)",
        message = "The node isn't exist",
        details = { uuid = uuid, parent_uuid = parent_uuid, data = data },
      })
      return self
    end

    if parent_uuid == nil then
      eve.reporter.error({
        from = __module_name__,
        subject = "update_leaf (ignored)",
        message = "The node isn't exist and the parent_uuid not provided",
        details = { uuid = uuid, parent_uuid = parent_uuid, data = data },
      })
      return self
    end

    return self:insert_leaf(uuid, parent_uuid, data)
  end

  if node.type ~= "leaf" then
    eve.reporter.warn({
      from = __module_name__,
      subject = "update_leaf (ignored)",
      message = "The exists node is not a leaf node",
      details = { uuid = uuid, parent_uuid = parent_uuid, data = data, old_node = node },
    })
    return self
  end

  parent_uuid = parent_uuid or node.parent ---@type string
  if node.parent == parent_uuid then
    node.data = data
    return self
  end

  local old_parent_node = self:retrieve_parent(uuid, node.parent) ---@type eve.ux.view.treeview.IContainerNode|nil
  if old_parent_node == nil then
    return self
  end

  local parent = self:retrieve_parent(uuid, parent_uuid) ---@type eve.ux.view.treeview.IContainerNode|nil
  if parent == nil then
    return self
  end

  old_parent_node.children = vim.tbl_filter(function(child_uuid)
    return child_uuid ~= uuid
  end, old_parent_node.children)

  node.data = data
  node.parent = parent_uuid
  node.depth = parent.depth + 1
  parent.children[#parent.children + 1] = uuid
  parent.dirty_orders = true
  return self
end

----------------------------------------------------------------------------------------------------

---@protected
---@param parent                        eve.ux.view.treeview.IContainerNode
---@return nil
function M:remove_recursively(parent)
  local node_map = self._node_map ---@type table<string, eve.ux.view.treeview.INode>
  node_map[parent.uuid] = nil

  for _, uuid in ipairs(parent.children) do
    local child = node_map[uuid] ---@type eve.ux.view.treeview.INode
    node_map[uuid] = nil
    if child.type == "container" then
      self:remove_recursively(child)
    end
  end
end

---@protected
---@param uuid                          string
---@param parent_uuid                   string
---@return eve.ux.view.treeview.IContainerNode|nil
function M:retrieve_parent(uuid, parent_uuid)
  if uuid == parent_uuid then
    return self._node_root
  end

  local parent = self._node_map[parent_uuid] ---@type eve.ux.view.treeview.INode|nil
  if parent == nil or parent.type ~= "container" then
    eve.reporter.error({
      from = __module_name__,
      subject = "retrieve_parent",
      message = "The expected parent is not a valid container node.",
      details = { uuid = uuid, parent_uuid = parent_uuid },
    })
    return nil
  end
  return parent
end

---@protected
---@param parent                        eve.ux.view.treeview.IContainerNode
---@return nil
function M:sort_container_node(parent)
  if not parent.dirty_orders then
    return self
  end

  parent.dirty_orders = false
  if parent.children > 1 then
    table.sort(parent.children, function(uuid_left, uuid_right)
      local left_node = self._node_map[uuid_left] ---@type eve.ux.view.treeview.INode
      local right_node = self._node_map[uuid_right] ---@type eve.ux.view.treeview.INode
      if left_node.type == right_node.type then
        return self._sorter(left_node.data, right_node.data)
      end
      return left_node.type == "container"
    end)
  end
end

---@protected
---@param parent                        eve.ux.view.treeview.IContainerNode
---@param collapsed                     boolean
---@return nil
function M:update_collapse_recursively(parent, collapsed)
  parent.collapsed = collapsed
  for _, uuid in ipairs(parent.children) do
    local child = self._node_map[uuid] ---@type eve.ux.view.treeview.INode
    if child.type == "container" then
      self:update_collapse_recursively(child, collapsed)
    end
  end
end

---@protected
---@param parent                        eve.ux.view.treeview.IContainerNode
---@return nil
function M:update_depth_recursively(parent)
  local depth = parent.depth + 1 ---@type integer
  local node_map = self._node_map ---@type table<string, eve.ux.view.treeview.INode>

  for _, uuid in ipairs(parent.children) do
    local child = node_map[uuid] ---@type eve.ux.view.treeview.INode
    child.depth = depth
    if child.type == "container" then
      self:update_depth_recursively(child)
    end
  end
end

return M
