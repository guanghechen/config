local __module_name__ = "std.collection.tree" ---@type string

---@alias std.collection.tree.ITraverseConditional
---| fun(uuid: string, cur: integer): boolean

---@alias std.collection.tree.ITraverseHandler
---| fun(uuid: string, cur: integer, is_lastchild: boolean, childcount: integer, onlychild: string|nil): nil

---@alias std.collection.tree.ITraverseRecursive
---| fun(uuid: std.collection.tree.INode, cur: integer, is_lastchild: boolean): nil

---@alias std.collection.tree.IQuickTraverseHandler
---| fun(uuid: string, cur: integer): nil

---@alias std.collection.tree.IQuickTraverseRecursive
---| fun(uuid: std.collection.tree.INode, cur: integer): nil

---@alias std.collection.tree.IUnsafeTraverseCallback
---| fun(root: std.collection.tree.INode, nodemap: table<string, std.collection.tree.INode>, cur: integer): nil

---@class std.collection.tree.INode
---@field public uuid                   string
---@field public parent                 string
---@field public children               string[]
---@field public depth                  integer
---@field public dirty_co               boolean children order dirty

---@alias std.collection.tree.INodeSorter
---| fun(uuid_left: string, uuid_right: string): boolean

----------------------------------------------------------------------------------------------------

---@class std.collection.ITreeProps
---@field public name                   string
---@field public node_sorter            std.collection.tree.INodeSorter

---@class std.collection.Tree
---@field public name                   string
---@field public root                   string
---@field public node_sorter            std.collection.tree.INodeSorter
---@field protected _disposed           boolean
---@field protected _nodemap            table<string, std.collection.tree.INode>
---@field protected _noderoot           std.collection.tree.INode
local M = {}
M.__index = M

---@param props                         std.collection.ITreeProps
---@return std.collection.Tree
function M.new(props)
  local alias = props.name ---@type string
  local name = string.format("%s@%s", __module_name__, alias) ---@type string
  local node_sorter = props.node_sorter ---@type std.collection.tree.INodeSorter
  local nodeuuid_root = "__virtual_root__" ---@type string

  ---@type std.collection.tree.INode
  local noderoot = {
    uuid = nodeuuid_root,
    parent = nodeuuid_root,
    children = {},
    depth = 0,
    dirty_co = false,
  }

  ---@type table<string, std.collection.tree.INode>
  local nodemap = {
    [nodeuuid_root] = noderoot,
  }

  local self = setmetatable({}, M)
  self.name = name
  self.root = nodeuuid_root
  self.node_sorter = node_sorter
  self._disposed = false
  self._nodemap = nodemap
  self._noderoot = noderoot
  return self
end

---@return std.collection.Tree
function M:clear()
  self:__health__()

  local nodemap = self._nodemap ---@type table<string, std.collection.tree.INode>
  local node_root = self._noderoot ---@type std.collection.tree.INode
  for _, uuid_child in ipairs(node_root.children) do
    local child = nodemap[uuid_child] ---@type std.collection.tree.INode
    self:__remove_recursive__(child)
  end
  node_root.children = {}
  node_root.dirty_co = false
  return self
end

---@return nil
function M:dispose()
  if self._disposed then
    return nil
  end
  self._disposed = true

  self:__remove_recursive__(self._noderoot)

  self.root = nil
  self.node_sorter = nil
  self._nodemap = nil
  self._noderoot = nil
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

  local nodemap = self._nodemap ---@type table<string, std.collection.tree.INode>

  local node = nodemap[uuid] ---@type std.collection.tree.INode|nil
  local node_ancestor = nodemap[ancestor] ---@type std.collection.tree.INode|nil
  if node == nil or node_ancestor == nil then
    return false
  end

  if node.depth <= node_ancestor.depth then
    return false
  end

  local distance = node.depth - node_ancestor.depth ---@type integer
  for _ = 1, distance, 1 do
    local node_parent = nodemap[node.parent] ---@type std.collection.tree.INode
    node = node_parent
  end
  return node.uuid == ancestor
end

---@param uuid                          string
---@return boolean
function M:isexist(uuid)
  self:__health__()
  return self._nodemap[uuid] ~= nil
end

---@param uuid                          string
---@return string|nil
function M:retrieve_parent(uuid)
  self:__health__()
  local node = self._nodemap[uuid] ---@type std.collection.tree.INode|nil
  return node ~= nil and node.parent or nil
end

---@param root                          string
---@param fn                            std.collection.tree.IQuickTraverseHandler
---@param conditional                   ?std.collection.tree.ITraverseConditional
---@return std.collection.Tree
function M:quick_traverse(root, fn, conditional)
  self:__health__()

  local nodemap = self._nodemap ---@type table<string, std.collection.tree.INode>
  local recursive ---@type std.collection.tree.IQuickTraverseRecursive

  if conditional == nil then
    ---@type std.collection.tree.IQuickTraverseRecursive
    recursive = function(node, cur)
      fn(node.uuid, cur)

      if node.dirty_co then
        self:__sort_children__(node)
      end

      local next_cur = cur + 1 ---@type integer
      local N = #node.children ---@type integer
      for index = 1, N, 1 do
        local uuid_child = node.children[index] ---@type string
        local child = nodemap[uuid_child] ---@type std.collection.tree.INode
        recursive(child, next_cur)
      end
    end
  else
    ---@type std.collection.tree.IQuickTraverseRecursive
    recursive = function(node, cur)
      fn(node.uuid, cur)

      if node.dirty_co then
        self:__sort_children__(node)
      end

      local next_cur = cur + 1 ---@type integer
      local N = #node.children ---@type integer
      for index = 1, N, 1 do
        local uuid_child = node.children[index] ---@type string
        if conditional(uuid_child, next_cur) then
          local child = nodemap[uuid_child] ---@type std.collection.tree.INode
          recursive(child, next_cur)
        end
      end
    end
  end

  local node_root = root and nodemap[root] or self._noderoot ---@type std.collection.tree.INode
  if node_root == self._noderoot then
    if node_root.dirty_co then
      self:__sort_children__(node_root)
    end

    for _, uuid_child in ipairs(node_root.children) do
      if conditional == nil or conditional(uuid_child, 1) then
        local node_child = nodemap[uuid_child] ---@type std.collection.tree.INode
        recursive(node_child, 1)
      end
    end
  else
    if conditional == nil or conditional(node_root.uuid, 1) then
      recursive(node_root, 1)
    end
  end

  return self
end

---@param root                          string
---@param fn                            std.collection.tree.ITraverseHandler
---@param conditional                   ?std.collection.tree.ITraverseConditional
---@return std.collection.Tree
function M:traverse(root, fn, conditional)
  self:__health__()

  local nodemap = self._nodemap ---@type table<string, std.collection.tree.INode>
  local recursive ---@type std.collection.tree.ITraverseRecursive

  if conditional == nil then
    ---@type std.collection.tree.ITraverseRecursive
    recursive = function(node, cur, is_lastchild)
      local N = #node.children ---@type integer
      local next_cur = cur + 1 ---@type integer

      if N == 0 then
        fn(node.uuid, cur, is_lastchild, 0, nil)
        return
      end

      if N == 1 then
        local uuid_child = node.children[1] ---@type string
        local node_child = nodemap[uuid_child] ---@type std.collection.tree.INode
        fn(node.uuid, cur, is_lastchild, 1, uuid_child)
        return recursive(node_child, next_cur, true)
      end

      fn(node.uuid, cur, is_lastchild, N, nil)

      if node.dirty_co then
        self:__sort_children__(node)
      end

      for index = 1, N, 1 do
        local uuid_child = node.children[index] ---@type string
        local child = nodemap[uuid_child] ---@type std.collection.tree.INode
        recursive(child, next_cur, index == N)
      end
    end
  else
    ---@type std.collection.tree.ITraverseRecursive
    recursive = function(node, cur, is_lastchild)
      if node.dirty_co then
        self:__sort_children__(node)
      end

      local N = 0 ---@type integer
      local next_cur = cur + 1 ---@type integer

      local first_child_index = 0 ---@type integer
      local last_child_index = #node.children ---@type integer
      for index, uuid_child in ipairs(node.children) do
        if conditional(uuid_child, next_cur) then
          N = N + 1 ---@type integer
          first_child_index = first_child_index or index ---@type integer
          last_child_index = index ---@type integer
        end
      end

      if N == 0 then
        fn(node.uuid, cur, is_lastchild, 0, nil)
        return
      end

      if N == 1 then
        local uuid_child = node.children[first_child_index] ---@type string
        local node_child = nodemap[uuid_child] ---@type std.collection.tree.INode
        fn(node.uuid, cur, is_lastchild, 1, uuid_child)
        return recursive(node_child, next_cur, true)
      end

      fn(node.uuid, cur, is_lastchild, N, nil)

      for index = first_child_index, last_child_index, 1 do
        local uuid_child = node.children[index] ---@type string
        if conditional(uuid_child, next_cur) then
          local node_child = nodemap[uuid_child] ---@type std.collection.tree.INode
          recursive(node_child, next_cur, index == last_child_index)
        end
      end
    end
  end

  local node_root = nodemap[root] or self._noderoot ---@type std.collection.tree.INode
  if node_root == self._noderoot then
    if node_root.dirty_co then
      self:__sort_children__(node_root)
    end

    for _, uuid_child in ipairs(node_root.children) do
      if conditional == nil or conditional(uuid_child, 1) then
        local node_child = nodemap[uuid_child] ---@type std.collection.tree.INode
        recursive(node_child, 1, true)
      end
    end
  else
    if conditional == nil or conditional(node_root.uuid, 1) then
      recursive(node_root, 1, true)
    end
  end

  return self
end

---@param root                          string|nil
---@param traverse                      std.collection.tree.IUnsafeTraverseCallback
---@return std.collection.Tree
function M:unsafe_traverse(root, traverse)
  self:__health__()
  local nodemap = self._nodemap ---@type table<string, std.collection.tree.INode>

  local node_root = nodemap[root] or self._noderoot ---@type std.collection.tree.INode
  if node_root == self._noderoot then
    if node_root.dirty_co then
      self:__sort_children__(node_root)
    end

    for _, uuid_child in ipairs(node_root.children) do
      local node_child = nodemap[uuid_child] ---@type std.collection.tree.INode
      traverse(node_child, nodemap, 1)
    end
  else
    traverse(node_root, nodemap, 1)
  end

  return self
end

----------------------------------------------------------------------------------------------------

---@param uuids                         string[]
---@return table<string, boolean>
function M:calc_include_uuid_set(uuids)
  self:__health__()

  local uuid_set = {} ---@type table<string, boolean>
  local nodemap = self._nodemap ---@type table<string, std.collection.tree.INode>
  for _, uuid in ipairs(uuids) do
    local id = uuid ---@type string
    while not uuid_set[id] do
      uuid_set[id] = true
      id = nodemap[id].parent ---@type string
    end
  end
  return uuid_set
end

---@param uuid                          string
---@return std.collection.Tree
function M:empty(uuid)
  self:__health__()

  local node_root = self._noderoot ---@type std.collection.tree.INode
  if uuid == node_root.uuid then
    return self:clear()
  end

  local nodemap = self._nodemap ---@type table<string, std.collection.tree.INode>
  local node = nodemap[uuid] ---@type std.collection.tree.INode|nil
  if node == nil then
    std.reporter.error({
      from = self.name,
      subject = "clear",
      message = string.format("Node with uuid '%s' does not exist.", uuid),
      details = {
        uuid = uuid,
      },
    })
    return self
  end

  for _, uuid_child in ipairs(node.children) do
    local node_child = nodemap[uuid_child] ---@type std.collection.tree.INode
    self:__remove_recursive__(node_child)
  end
  node.children = {}
  node.dirty_co = false

  return self
end

---@param uuid                          string
---@param parent                        string
---@return std.collection.Tree
function M:insert(uuid, parent)
  self:__health__()

  local nodemap = self._nodemap ---@type table<string, std.collection.tree.INode>
  local node_parent = uuid ~= parent and nodemap[parent] or self._noderoot ---@type std.collection.tree.INode
  local node = nodemap[uuid] ---@type std.collection.tree.INode|nil
  if node == nil then
    ---@type std.collection.tree.INode
    node = {
      uuid = uuid,
      parent = node_parent.uuid,
      children = {},
      depth = node_parent.depth + 1,
      dirty_co = false,
    }
    nodemap[uuid] = node
  else
    if node.parent == node_parent.uuid then
      return self
    end

    local old_node_parent = nodemap[node.parent] ---@type std.collection.tree.INode
    std.table.filter_inline(old_node_parent.children, function(uuid_child)
      return uuid_child ~= node.uuid
    end)

    node.parent = node_parent.uuid
    if old_node_parent.depth ~= node_parent.depth then
      self:__resolve_depth_recursive__(node, node_parent.depth + 1)
    end
  end

  node_parent.children[#node_parent.children + 1] = uuid
  node_parent.dirty_co = true
  return self
end

---@param uuid                          string
---@return std.collection.Tree
function M:remove(uuid)
  self:__health__()

  local node_root = self._noderoot ---@type std.collection.tree.INode
  if uuid == node_root.uuid then
    return self:clear()
  end

  local nodemap = self._nodemap ---@type table<string, std.collection.tree.INode>
  local node = nodemap[uuid] ---@type std.collection.tree.INode|nil
  if node == nil then
    std.reporter.error({
      from = self.name,
      subject = "remove",
      message = string.format("Node with uuid '%s' does not exist.", uuid),
      details = {
        uuid = uuid,
      },
    })
    return self
  end

  local node_parent = nodemap[node.parent] ---@type std.collection.tree.INode
  std.table.filter_inline(node_parent.children, function(uuid_child)
    return uuid_child ~= uuid
  end)
  self:__remove_recursive__(node)

  return self
end

----------------------------------------------------------------------------------------------------

---@protected
---@return nil
function M:__health__()
  if self._disposed then
    local message = string.format("%s has been disposed.", self.name) ---@type string
    error(message)
  end
end

---@protected
---@param node                          std.collection.tree.INode
---@return nil
function M:__remove_recursive__(node)
  local nodemap = self._nodemap ---@type table<string, std.collection.tree.INode>
  for _, uuid_child in ipairs(node.children) do
    local child = nodemap[uuid_child] ---@type std.collection.tree.INode
    self:__remove_recursive__(child)
  end

  nodemap[node.uuid] = nil
  node.uuid = nil
  node.parent = nil
  node.children = nil
  node.depth = nil
end

---@protected
---@param node                          std.collection.tree.INode
---@param depth                         integer
---@return nil
function M:__resolve_depth_recursive__(node, depth)
  node.depth = depth
  for _, uuid_child in ipairs(node.children) do
    local child = self._nodemap[uuid_child] ---@type std.collection.tree.INode
    self:__resolve_depth_recursive__(child, depth + 1)
  end
end

---@protected
---@param node                          std.collection.tree.INode
---@return nil
function M:__sort_children__(node)
  node.dirty_co = false
  if #node.children > 1 then
    table.sort(node.children, self.node_sorter)
  end
end

return M
