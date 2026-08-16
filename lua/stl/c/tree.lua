---@diagnostic disable-next-line: unused-local
local __module_name__ = "stl.c.tree" ---@type string

---@class stl.c.ITreeNode
---@field public uuid                   string
---@field public parent                 string
---@field public children               string[]
---@field public depth                  integer
---@field public data                   table
---@field public dirty_co               boolean children order dirty

----------------------------------------------------------------------------------------------------

---@class stl.c.IReadonlyTree
---@field public fullname               string
---@field public root                   string
---@field public isdisposed             fun(self: stl.c.IReadonlyTree): boolean
---@field public isdescendant           fun(self: stl.c.IReadonlyTree, ancestor: string, uuid: string): boolean
---@field public get                    fun(self: stl.c.IReadonlyTree, uuid: string): unknown|nil
---@field public contains               fun(self: stl.c.IReadonlyTree, uuid: string): boolean
---@field public parent                 fun(self: stl.c.IReadonlyTree, uuid: string): string|nil
---@field public children               fun(self: stl.c.IReadonlyTree, uuid: string): string[]|nil

---@class stl.c.ITree : stl.c.IReadonlyTree
---@field public fullname               string
---@field public root                   string
---@field public clear                  fun(self: stl.c.ITree): stl.c.ITree
---@field public dispose                fun(self: stl.c.ITree): nil
---@field public isdisposed             fun(self: stl.c.ITree): boolean
---@field public isdescendant           fun(self: stl.c.ITree, ancestor: string, uuid: string): boolean
---@field public get                    fun(self: stl.c.ITree, uuid: string): unknown|nil
---@field public contains               fun(self: stl.c.ITree, uuid: string): boolean
---@field public parent                 fun(self: stl.c.ITree, uuid: string): string|nil
---@field public children               fun(self: stl.c.ITree, uuid: string): string[]|nil
---@field public insert                 fun(self: stl.c.ITree, parent: string, uuid: string, data: table|nil, index?: integer): stl.c.ITree
---@field public update                 fun(self: stl.c.ITree, uuid: string, data: table): stl.c.ITree
---@field public move                   fun(self: stl.c.ITree, uuid: string, parent: string, index?: integer): stl.c.ITree
---@field public remove                 fun(self: stl.c.ITree, uuid: string): stl.c.ITree

---@class stl.c.Tree : stl.c.ITree
---@field public fullname               string
---@field public root                   string
---@field protected _disposed           boolean
---@field protected _nodemap            table<string, stl.c.ITreeNode>
---@field protected _rootnode           stl.c.ITreeNode
local M = {}
M.__index = M

---@param root                          string
---@param rootdata?                     table
---@return stl.c.Tree
function M.new(root, rootdata)
  if type(root) ~= "string" then
    error(string.format("[%s] root must be a string", __module_name__), 2)
  end
  local fullname = string.format("%s@%s", __module_name__, root) ---@type string
  local rootnodedata = rootdata ~= nil and rootdata or {} ---@type unknown

  ---@type stl.c.ITreeNode
  local noderoot = {
    uuid = root,
    parent = root,
    children = {},
    depth = 0,
    data = rootnodedata,
    dirty_co = false,
  }

  ---@type table<string, stl.c.ITreeNode>
  local nodemap = {
    [root] = noderoot,
  }

  local self = setmetatable({}, M)
  self.fullname = fullname
  self.root = root
  self._disposed = false
  self._nodemap = nodemap
  self._rootnode = noderoot
  return self
end

---@return stl.c.Tree
function M:clear()
  self:__health__()

  local nodemap = self._nodemap ---@type table<string, stl.c.ITreeNode>
  local rootnode = self._rootnode ---@type stl.c.ITreeNode
  for _, childuuid in ipairs(rootnode.children) do
    local child = nodemap[childuuid] ---@type stl.c.ITreeNode
    self:__remove_recursive__(child)
  end
  rootnode.children = {}
  rootnode.dirty_co = false
  return self
end

---@return nil
function M:dispose()
  if self._disposed then
    return nil
  end
  self._disposed = true

  self:__remove_recursive__(self._rootnode)

  self.root = nil
  self._nodemap = nil
  self._rootnode = nil
end

---@return boolean
function M:isdisposed()
  return self._disposed
end

----------------------------------------------------------------------------------------------------

---@param ancestor                      string
---@param uuid                          string
---@return boolean
function M:isdescendant(ancestor, uuid)
  self:__health__()

  if ancestor == uuid then
    return true
  end

  local nodemap = self._nodemap ---@type table<string, stl.c.ITreeNode>

  local node = nodemap[uuid] ---@type stl.c.ITreeNode|nil
  local node_ancestor = nodemap[ancestor] ---@type stl.c.ITreeNode|nil
  if node == nil or node_ancestor == nil then
    return false
  end

  if node.depth <= node_ancestor.depth then
    return false
  end

  local distance = node.depth - node_ancestor.depth ---@type integer
  for _ = 1, distance, 1 do
    node = nodemap[node.parent] ---@type stl.c.ITreeNode
  end
  return node.uuid == ancestor
end

---@param uuid                          string
---@return unknown|nil
function M:get(uuid)
  self:__health__()
  local node = self._nodemap[uuid] ---@type stl.c.ITreeNode|nil
  return node ~= nil and node.data or nil
end

---@param uuid                          string
---@return boolean
function M:contains(uuid)
  self:__health__()
  return self._nodemap[uuid] ~= nil
end

---@param uuid                          string
---@return string|nil
function M:parent(uuid)
  self:__health__()
  local node = self._nodemap[uuid] ---@type stl.c.ITreeNode|nil
  if node == nil or node == self._rootnode then
    return nil
  end
  return node.parent
end

---@param uuid                          string
---@return string[]|nil Read-only borrowed child IDs in traversal order.
function M:children(uuid)
  self:__health__()

  local node = self._nodemap[uuid] ---@type stl.c.ITreeNode|nil
  if node == nil then
    return nil
  end

  if node.dirty_co then
    self:__sort_children__(node)
  end
  return node.children
end

---@param uuid                          string
---@param data                          table
---@return stl.c.Tree
function M:update(uuid, data)
  self:__health__()
  local node = self._nodemap[uuid] ---@type stl.c.ITreeNode|nil
  if node == nil then
    error(string.format("[%s] node '%s' does not exist", __module_name__, uuid), 2)
  end
  node.data = data
  return self
end

---@param uuid                          string
---@param parent                        string
---@param index?                        integer
---@return stl.c.Tree
function M:move(uuid, parent, index)
  self:__health__()
  local nodemap = self._nodemap ---@type table<string, stl.c.ITreeNode>
  local node = nodemap[uuid] ---@type stl.c.ITreeNode|nil
  local next_parent = nodemap[parent] ---@type stl.c.ITreeNode|nil
  if node == nil then
    error(string.format("[%s] node '%s' does not exist", __module_name__, uuid), 2)
  end
  if next_parent == nil then
    error(string.format("[%s] parent '%s' does not exist", __module_name__, parent), 2)
  end
  if node == self._rootnode then
    error(string.format("[%s] root cannot be moved", __module_name__), 2)
  end
  if self:isdescendant(uuid, parent) then
    error(string.format("[%s] moving '%s' below '%s' would create a cycle", __module_name__, uuid, parent), 2)
  end
  if node.parent == parent and index == nil then
    return self
  end

  local old_parent = nodemap[node.parent] ---@type stl.c.ITreeNode
  local max_index = old_parent == next_parent and #next_parent.children or (#next_parent.children + 1) ---@type integer
  local insertion_index = index or max_index ---@type integer
  if
    type(insertion_index) ~= "number"
    or insertion_index % 1 ~= 0
    or insertion_index < 1
    or insertion_index > max_index
  then
    error(string.format("[%s] child index out of range: %s", __module_name__, tostring(index)), 2)
  end

  stl.table.filter_inline(old_parent.children, function(child_id)
    return child_id ~= uuid
  end)
  table.insert(next_parent.children, insertion_index, uuid)
  node.parent = parent
  if node.depth ~= next_parent.depth + 1 then
    self:__resolve_depth_recursive__(node, next_parent.depth + 1)
  end
  return self
end

---@generic T : table
---@param parent                        string
---@param uuid                          string
---@param data                          T
---@param index?                        integer
---@return stl.c.Tree
function M:insert(parent, uuid, data, index)
  self:__health__()

  local nodemap = self._nodemap ---@type table<string, stl.c.ITreeNode>
  local node = nodemap[uuid] ---@type stl.c.ITreeNode|nil

  local node_parent = nodemap[parent] ---@type stl.c.ITreeNode|nil
  if node_parent == nil then
    error(string.format("[%s] parent '%s' does not exist", __module_name__, parent), 2)
  end
  if node ~= nil then
    error(string.format("[%s] node '%s' already exists", __module_name__, uuid), 2)
  end
  local insertion_index = index or (#node_parent.children + 1) ---@type integer
  if
    type(insertion_index) ~= "number"
    or insertion_index % 1 ~= 0
    or insertion_index < 1
    or insertion_index > #node_parent.children + 1
  then
    error(string.format("[%s] child index out of range: %s", __module_name__, tostring(index)), 2)
  end
  node = {
    uuid = uuid,
    parent = parent,
    children = {},
    depth = node_parent.depth + 1,
    data = data,
    dirty_co = false,
  }
  nodemap[uuid] = node
  table.insert(node_parent.children, insertion_index, uuid)
  return self
end

---@param nodeuuid                      string
---@return stl.c.Tree
function M:remove(nodeuuid)
  self:__health__()

  local rootnode = self._rootnode ---@type stl.c.ITreeNode
  if nodeuuid == rootnode.uuid then
    error(string.format("[%s] root cannot be removed", __module_name__), 2)
  end

  local nodemap = self._nodemap ---@type table<string, stl.c.ITreeNode>
  local node = nodemap[nodeuuid] ---@type stl.c.ITreeNode|nil
  if node == nil then
    error(string.format("[%s] node '%s' does not exist", __module_name__, nodeuuid), 2)
  end

  local node_parent = nodemap[node.parent] ---@type stl.c.ITreeNode

  self:__remove_recursive__(node)
  stl.table.filter_inline(node_parent.children, function(childuuid)
    return childuuid ~= nodeuuid
  end)

  return self
end

----------------------------------------------------------------------------------------------------

---@protected
---@return nil
function M:__health__()
  if self._disposed then
    local message = string.format("%s has been disposed.", self.fullname) ---@type string
    error(message)
  end
end

---@protected
---@param node                          stl.c.ITreeNode
---@return nil
function M:__remove_recursive__(node)
  local nodemap = self._nodemap ---@type table<string, stl.c.ITreeNode>
  local stack_nodes = { node } ---@type stl.c.ITreeNode[]
  local stack_indexes = { 1 } ---@type integer[]
  local stack_size = 1 ---@type integer
  while stack_size > 0 do
    local current = stack_nodes[stack_size] ---@type stl.c.ITreeNode
    local child_index = stack_indexes[stack_size] ---@type integer
    if child_index <= #current.children then
      stack_indexes[stack_size] = child_index + 1
      local child = nodemap[current.children[child_index]] ---@type stl.c.ITreeNode|nil
      if child ~= nil then
        stack_size = stack_size + 1
        stack_nodes[stack_size] = child
        stack_indexes[stack_size] = 1
      end
    else
      nodemap[current.uuid] = nil
      current.uuid = nil
      current.parent = nil
      current.children = nil
      current.depth = nil
      stack_nodes[stack_size] = nil
      stack_indexes[stack_size] = nil
      stack_size = stack_size - 1
    end
  end
end

---@protected
---@param node                          stl.c.ITreeNode
---@param depth                         integer
---@return nil
function M:__resolve_depth_recursive__(node, depth)
  local nodemap = self._nodemap ---@type table<string, stl.c.ITreeNode>
  local stack_nodes = { node } ---@type stl.c.ITreeNode[]
  local stack_indexes = { 1 } ---@type integer[]
  local stack_size = 1 ---@type integer
  node.depth = depth
  while stack_size > 0 do
    local current = stack_nodes[stack_size] ---@type stl.c.ITreeNode
    local child_index = stack_indexes[stack_size] ---@type integer
    if child_index <= #current.children then
      stack_indexes[stack_size] = child_index + 1
      local child = nodemap[current.children[child_index]] ---@type stl.c.ITreeNode
      child.depth = current.depth + 1
      stack_size = stack_size + 1
      stack_nodes[stack_size] = child
      stack_indexes[stack_size] = 1
    else
      stack_nodes[stack_size] = nil
      stack_indexes[stack_size] = nil
      stack_size = stack_size - 1
    end
  end
end

---@protected
---@param node                          stl.c.ITreeNode
---@return nil
function M:__sort_children__(node)
  node.dirty_co = false
end

return M
