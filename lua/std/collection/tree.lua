local __module_name__ = "std.collection.tree" ---@type string

---@alias std.collection.tree.TraverseConditionalEnum
---| "badroot"  -- Don't handle current node and its descendants
---| "goodnode" -- Handle current node, but don't traverse its descendants
---| "goodroot" -- Handle current node and its descendants

---@alias std.collection.tree.INodeSorter
---| fun(left: std.collection.tree.INode, right: std.collection.tree.INode): boolean

---@alias std.collection.tree.ITraverseConditional
---| fun(ctx: std.collection.tree.ITraverseContext, node: std.collection.tree.INode, cur: integer): std.collection.tree.TraverseConditionalEnum

---@alias std.collection.tree.ITraverseHandler
---| fun(ctx: std.collection.tree.ITraverseContext, node: std.collection.tree.INode, cur: integer, is_lastchild: boolean, onlychild: string|nil, childcount: integer): nil

---@alias std.collection.tree.ITraverseRecursive
---| fun(ctx: std.collection.tree.ITraverseContext, node: std.collection.tree.INode, cur: integer, is_lastchild: boolean): nil

---@alias std.collection.tree.IQuickTraverseHandler
---| fun(ctx: std.collection.tree.ITraverseContext, node: std.collection.tree.INode, cur: integer): nil

---@alias std.collection.tree.IQuickTraverseRecursive
---| fun(ctx: std.collection.tree.ITraverseContext, node: std.collection.tree.INode, cur: integer): nil

---@alias std.collection.tree.IUnsafeTraverseCallback
---| fun(ctx: std.collection.tree.ITraverseContext): nil

---@class std.collection.tree.ITraverseContext
---@field public nodemap                table<string, std.collection.tree.INode>
---@field public rootnode               std.collection.tree.INode

---@class std.collection.tree.INode
---@field public uuid                   string
---@field public parent                 string
---@field public children               string[]
---@field public depth                  integer
---@field public data                   table
---@field public dirty_co               boolean children order dirty

----------------------------------------------------------------------------------------------------

---@class std.collection.ITreeProps
---@field public fullname               string|nil
---@field public name                   string
---@field public node_sorter            std.collection.tree.INodeSorter
---@field public rootnodedata           unknown|nil

---@class std.collection.IReadonlyTree
---@field public fullname               string
---@field public root                   string
---@field public isdisposed             fun(self: std.collection.IReadonlyTree): boolean
---@field public isdescendant           fun(self: std.collection.IReadonlyTree, ancestor: string, uuid: string): boolean
---@field public isexistent             fun(self: std.collection.IReadonlyTree, uuid: string): boolean
---@field public retrieve               fun(self: std.collection.IReadonlyTree, uuid: string): std.collection.tree.INode|nil
---@field public quick_traverse         fun(self: std.collection.IReadonlyTree, root: string|nil, fn: std.collection.tree.IQuickTraverseHandler, conditional: std.collection.tree.ITraverseConditional|nil): std.collection.IReadonlyTree
---@field public traverse               fun(self: std.collection.IReadonlyTree, root: string|nil, fn: std.collection.tree.ITraverseHandler, conditional: std.collection.tree.ITraverseConditional|nil): std.collection.IReadonlyTree
---@field public unsafe_traverse        fun(self: std.collection.IReadonlyTree, root: string|nil, traverse: std.collection.tree.IUnsafeTraverseCallback): std.collection.IReadonlyTree
---@field public calc_include_uuid_set  fun(self: std.collection.IReadonlyTree, uuids: string[]): table<string, boolean>

---@class std.collection.ITree : std.collection.IReadonlyTree
---@field public fullname               string
---@field public root                   string
---@field public clear                  fun(self: std.collection.ITree): std.collection.ITree
---@field public dispose                fun(self: std.collection.ITree): nil
---@field public isdisposed             fun(self: std.collection.ITree): boolean
---@field public isdescendant           fun(self: std.collection.ITree, ancestor: string, uuid: string): boolean
---@field public isexistent             fun(self: std.collection.ITree, uuid: string): boolean
---@field public retrieve               fun(self: std.collection.ITree, uuid: string): std.collection.tree.INode|nil
---@field public quick_traverse         fun(self: std.collection.ITree, root: string|nil, fn: std.collection.tree.IQuickTraverseHandler, conditional: std.collection.tree.ITraverseConditional|nil): std.collection.ITree
---@field public traverse               fun(self: std.collection.ITree, root: string|nil, fn: std.collection.tree.ITraverseHandler, conditional: std.collection.tree.ITraverseConditional|nil): std.collection.ITree
---@field public unsafe_traverse        fun(self: std.collection.ITree, root: string|nil, traverse: std.collection.tree.IUnsafeTraverseCallback): std.collection.ITree
---@field public calc_include_uuid_set  fun(self: std.collection.ITree, uuids: string[]): table<string, boolean>
---@field public empty                  fun(self: std.collection.ITree, uuid: string): std.collection.ITree
---@field public insert                 fun(self: std.collection.ITree, parent: string, uuid: string, data: table|nil): std.collection.tree.INode
---@field public remove                 fun(self: std.collection.ITree, uuid: string): std.collection.ITree

---@class std.collection.Tree : std.collection.ITree
---@field public fullname               string
---@field public root                   string
---@field public node_sorter            std.collection.tree.INodeSorter
---@field protected _disposed           boolean
---@field protected _nodemap            table<string, std.collection.tree.INode>
---@field protected _rootnode           std.collection.tree.INode
local M = {}
M.__index = M

---@param props                         std.collection.ITreeProps
---@return std.collection.Tree
function M.new(props)
  local name = props.name ---@type string
  local fullname = props.fullname or string.format("%s@%s", __module_name__, name) ---@type string
  local node_sorter = props.node_sorter ---@type std.collection.tree.INodeSorter
  local rootnodedata = props.rootnodedata or {} ---@type unknown
  local uuid_root = "__virtual_root__" ---@type string

  ---@type std.collection.tree.INode
  local noderoot = {
    uuid = uuid_root,
    parent = uuid_root,
    children = {},
    depth = 0,
    data = rootnodedata,
    dirty_co = false,
  }

  ---@type table<string, std.collection.tree.INode>
  local nodemap = {
    [uuid_root] = noderoot,
  }

  local self = setmetatable({}, M)
  self.fullname = fullname
  self.root = uuid_root
  self.node_sorter = node_sorter
  self._disposed = false
  self._nodemap = nodemap
  self._rootnode = noderoot
  return self
end

---@return std.collection.Tree
function M:clear()
  self:__health__()

  local nodemap = self._nodemap ---@type table<string, std.collection.tree.INode>
  local rootnode = self._rootnode ---@type std.collection.tree.INode
  for _, childuuid in ipairs(rootnode.children) do
    local child = nodemap[childuuid] ---@type std.collection.tree.INode
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
  self.node_sorter = nil
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
    node = nodemap[node.parent] ---@type std.collection.tree.INode
  end
  return node.uuid == ancestor
end

---@param uuid                          string
---@return boolean
function M:isexistent(uuid)
  self:__health__()
  return self._nodemap[uuid] ~= nil
end

---@param uuid                          string
---@return std.collection.tree.INode|nil
function M:retrieve(uuid)
  self:__health__()
  return self._nodemap[uuid] ---@type std.collection.tree.INode|nil
end

---@param root                          string
---@param fn                            std.collection.tree.IQuickTraverseHandler
---@param conditional                   ?std.collection.tree.ITraverseConditional
---@return std.collection.Tree
function M:quick_traverse(root, fn, conditional)
  self:__health__()

  local nodemap = self._nodemap ---@type table<string, std.collection.tree.INode>
  local recursive ---@type std.collection.tree.IQuickTraverseRecursive
  local rootnode = root and nodemap[root] or self._rootnode ---@type std.collection.tree.INode

  if conditional == nil then
    ---@type std.collection.tree.IQuickTraverseRecursive
    recursive = function(ctx, node, cur)
      fn(ctx, node, cur)

      if node.dirty_co then
        self:__sort_children__(node)
      end

      local next_cur = cur + 1 ---@type integer
      local N = #node.children ---@type integer
      for index = 1, N, 1 do
        local childuuid = node.children[index] ---@type string
        local child = nodemap[childuuid] ---@type std.collection.tree.INode
        recursive(ctx, child, next_cur)
      end
    end
  else
    ---@type std.collection.tree.IQuickTraverseRecursive
    recursive = function(ctx, node, cur)
      local condition = conditional(ctx, node, cur) ---@type std.collection.tree.TraverseConditionalEnum
      if condition == "badroot" then
        return
      end

      if condition == "goodnode" then
        fn(ctx, node, cur)
        return
      end

      fn(ctx, node, cur)

      if node.dirty_co then
        self:__sort_children__(node)
      end

      local next_cur = cur + 1 ---@type integer
      local N = #node.children ---@type integer
      for index = 1, N, 1 do
        local childuuid = node.children[index] ---@type string
        local child = nodemap[childuuid] ---@type std.collection.tree.INode
        recursive(ctx, child, next_cur)
      end
    end
  end

  if rootnode == self._rootnode then
    if rootnode.dirty_co then
      self:__sort_children__(rootnode)
    end

    for _, childuuid in ipairs(rootnode.children) do
      local childnode = nodemap[childuuid] ---@type std.collection.tree.INode
      local ctx = { nodemap = nodemap, rootnode = childnode } ---@type std.collection.tree.ITraverseContext
      recursive(ctx, childnode, 1)
    end
  else
    local ctx = { nodemap = nodemap, rootnode = rootnode } ---@type std.collection.tree.ITraverseContext
    recursive(ctx, rootnode, 1)
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
    recursive = function(ctx, node, cur, is_lastchild)
      local N = #node.children ---@type integer
      local next_cur = cur + 1 ---@type integer

      if N == 0 then
        fn(ctx, node, cur, is_lastchild, nil, N)
        return
      end

      if N == 1 then
        local childuuid = node.children[1] ---@type string
        local childnode = nodemap[childuuid] ---@type std.collection.tree.INode
        fn(ctx, node, cur, is_lastchild, childuuid, N)
        return recursive(ctx, childnode, next_cur, true)
      end

      fn(ctx, node, cur, is_lastchild, nil, N)

      if node.dirty_co then
        self:__sort_children__(node)
      end

      for index = 1, N, 1 do
        local childuuid = node.children[index] ---@type string
        local child = nodemap[childuuid] ---@type std.collection.tree.INode
        recursive(ctx, child, next_cur, index == N)
      end
    end
  else
    ---@type std.collection.tree.ITraverseRecursive
    recursive = function(ctx, node, cur, is_lastchild)
      local condition = conditional(ctx, node, cur) ---@type std.collection.tree.TraverseConditionalEnum
      if condition == "badroot" then
        return
      end

      if condition == "goodnode" then
        fn(ctx, node, cur, is_lastchild, nil, 0)
        return
      end

      if node.dirty_co then
        self:__sort_children__(node)
      end

      local N = 0 ---@type integer
      local next_cur = cur + 1 ---@type integer

      local first_child_index = nil ---@type integer|nil
      local last_child_index = #node.children ---@type integer
      for index, childuuid in ipairs(node.children) do
        local child = nodemap[childuuid] ---@type std.collection.tree.INode
        local child_condition = conditional(ctx, child, next_cur) ---@type std.collection.tree.TraverseConditionalEnum
        if child_condition ~= "badroot" then
          N = N + 1 ---@type integer
          first_child_index = first_child_index or index ---@type integer
          last_child_index = index ---@type integer
        end
      end

      if first_child_index == nil then
        fn(ctx, node, cur, is_lastchild, nil, N)
        return
      end

      if N == 1 then
        local childuuid = node.children[first_child_index] ---@type string
        local childnode = nodemap[childuuid] ---@type std.collection.tree.INode
        fn(ctx, node, cur, is_lastchild, childuuid, N)
        return recursive(ctx, childnode, next_cur, true)
      end

      fn(ctx, node, cur, is_lastchild, nil, N)

      for index = first_child_index, last_child_index, 1 do
        local childuuid = node.children[index] ---@type string
        local childnode = nodemap[childuuid] ---@type std.collection.tree.INode
        recursive(ctx, childnode, next_cur, index == last_child_index)
      end
    end
  end

  local rootnode = nodemap[root] or self._rootnode ---@type std.collection.tree.INode
  if rootnode == self._rootnode then
    if rootnode.dirty_co then
      self:__sort_children__(rootnode)
    end

    for _, childuuid in ipairs(rootnode.children) do
      local childnode = nodemap[childuuid] ---@type std.collection.tree.INode
      local ctx = { nodemap = nodemap, rootnode = childnode } ---@type std.collection.tree.ITraverseContext
      recursive(ctx, childnode, 1, true)
    end
  else
    local ctx = { nodemap = nodemap, rootnode = rootnode } ---@type std.collection.tree.ITraverseContext
    recursive(ctx, rootnode, 1, true)
  end

  return self
end

---@param root                          string|nil
---@param traverse                      std.collection.tree.IUnsafeTraverseCallback
---@return std.collection.Tree
function M:unsafe_traverse(root, traverse)
  self:__health__()
  local nodemap = self._nodemap ---@type table<string, std.collection.tree.INode>

  local rootnode = nodemap[root] or self._rootnode ---@type std.collection.tree.INode
  if rootnode == self._rootnode then
    if rootnode.dirty_co then
      self:__sort_children__(rootnode)
    end

    for _, childuuid in ipairs(rootnode.children) do
      local childnode = nodemap[childuuid] ---@type std.collection.tree.INode
      local ctx = { nodemap = nodemap, rootnode = childnode } ---@type std.collection.tree.ITraverseContext
      traverse(ctx)
    end
  else
    local ctx = { nodemap = nodemap, rootnode = rootnode } ---@type std.collection.tree.ITraverseContext
    traverse(ctx)
  end

  return self
end

----------------------------------------------------------------------------------------------------

---@param uuids                         string[]
---@return table<string, boolean>
function M:calc_include_uuid_set(uuids)
  self:__health__()

  local uuidset = {} ---@type table<string, boolean>
  local nodemap = self._nodemap ---@type table<string, std.collection.tree.INode>
  local N = #uuids ---@type integer
  for index = 1, N, 1 do
    local uuid = uuids[index] ---@type string
    while not uuidset[uuid] do
      uuidset[uuid] = true
      uuid = nodemap[uuid].parent ---@type string
    end
  end
  return uuidset
end

---@param uuid                          string
---@return std.collection.Tree
function M:empty(uuid)
  self:__health__()

  local rootnode = self._rootnode ---@type std.collection.tree.INode
  if uuid == rootnode.uuid then
    return self:clear()
  end

  local nodemap = self._nodemap ---@type table<string, std.collection.tree.INode>
  local node = nodemap[uuid] ---@type std.collection.tree.INode|nil
  if node == nil then
    std.reporter.error({
      from = self.fullname,
      subject = "clear",
      message = string.format("Node with uuid '%s' does not exist.", uuid),
      details = {
        uuid = uuid,
      },
    })
    return self
  end

  for _, childuuid in ipairs(node.children) do
    local childnode = nodemap[childuuid] ---@type std.collection.tree.INode
    self:__remove_recursive__(childnode)
  end
  node.children = {}
  node.dirty_co = false

  return self
end

---@generic T : table
---@param parent                        string
---@param uuid                          string
---@param data                          T
---@return std.collection.tree.INode
function M:insert(parent, uuid, data)
  self:__health__()

  local nodemap = self._nodemap ---@type table<string, std.collection.tree.INode>
  local node = nodemap[uuid] ---@type std.collection.tree.INode|nil

  local node_parent = parent ~= uuid and nodemap[parent] or self._rootnode ---@type std.collection.tree.INode
  parent = node_parent.uuid ---@type string

  if node == nil then
    ---@type std.collection.tree.INode
    node = {
      uuid = uuid,
      parent = node_parent.uuid,
      children = {},
      depth = node_parent.depth + 1,
      data = data,
      dirty_co = false,
    }
    nodemap[uuid] = node
  else
    node.data = data
    if node.parent == node_parent.uuid then
      return node
    end

    local old_node_parent = nodemap[node.parent] ---@type std.collection.tree.INode
    std.table.filter_inline(old_node_parent.children, function(childuuid)
      return childuuid ~= node.uuid
    end)

    node.parent = node_parent.uuid
    if old_node_parent.depth ~= node_parent.depth then
      self:__resolve_depth_recursive__(node, node_parent.depth + 1)
    end
  end

  node_parent.children[#node_parent.children + 1] = uuid
  node_parent.dirty_co = true
  return node
end

---@param rootuuid                      string|nil
---@return string[]
function M:print(rootuuid)
  self:__health__()

  local nodemap = self._nodemap ---@type table<string, std.collection.tree.INode>
  local rootnode = rootuuid and nodemap[rootuuid] or self._rootnode ---@type std.collection.tree.INode
  local lines = {} ---@type string[]

  ---@param node                        std.collection.tree.INode
  ---@param indent                      string
  ---@param is_lastchild                boolean
  ---@param depth                       integer
  local function recursive(node, indent, is_lastchild, depth)
    local childindent = depth > 0 and (indent .. (is_lastchild and "  " or "│ ")) or "" ---@type string
    local connector = depth > 0 and (is_lastchild and "╰─" or "├─") or "" ---@type string
    lines[#lines + 1] = string.format("%s%s%s", indent, connector, node.data.name or node.uuid)

    if node.dirty_co then
      self:__sort_children__(node)
    end

    local N = #node.children ---@type integer
    for index = 1, N, 1 do
      local childuuid = node.children[index] ---@type string
      local child = nodemap[childuuid] ---@type std.collection.tree.INode
      if child then
        recursive(child, childindent, index == N, depth + 1)
      end
    end
  end

  if rootnode == self._rootnode then
    if rootnode.dirty_co then
      self:__sort_children__(rootnode)
    end

    local N = #rootnode.children
    for index = 1, N do
      local childuuid = rootnode.children[index]
      local child = nodemap[childuuid]
      if child then
        recursive(child, "", index == N, 0)
      end
    end
    return lines
  end

  if rootnode.dirty_co then
    self:__sort_children__(rootnode)
  end

  lines[#lines + 1] = (rootnode.data.name or rootnode.uuid) ---@type string

  local N = #rootnode.children
  for index = 1, N do
    local childuuid = rootnode.children[index]
    local child = nodemap[childuuid]
    if child then
      recursive(child, "", index == N, 1)
    end
  end
  return lines
end

---@param nodeuuid                      string
---@return std.collection.Tree
function M:remove(nodeuuid)
  self:__health__()

  local rootnode = self._rootnode ---@type std.collection.tree.INode
  if nodeuuid == rootnode.uuid then
    return self:clear()
  end

  local nodemap = self._nodemap ---@type table<string, std.collection.tree.INode>
  local node = nodemap[nodeuuid] ---@type std.collection.tree.INode|nil
  if node == nil then
    std.reporter.error({
      from = self.fullname,
      subject = "remove",
      message = string.format("Node with uuid '%s' does not exist.", nodeuuid),
      details = {
        uuid = nodeuuid,
      },
    })
    return self
  end

  local node_parent = nodemap[node.parent] ---@type std.collection.tree.INode

  self:__remove_recursive__(node)
  std.table.filter_inline(node_parent.children, function(childuuid)
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
---@param node                          std.collection.tree.INode
---@return nil
function M:__remove_recursive__(node)
  local nodemap = self._nodemap ---@type table<string, std.collection.tree.INode>
  for _, childuuid in ipairs(node.children) do
    local child = nodemap[childuuid] ---@type std.collection.tree.INode|nil
    if child ~= nil then
      self:__remove_recursive__(child)
    end
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
  for _, childuuid in ipairs(node.children) do
    local child = self._nodemap[childuuid] ---@type std.collection.tree.INode
    self:__resolve_depth_recursive__(child, depth + 1)
  end
end

---@protected
---@param node                          std.collection.tree.INode
---@return nil
function M:__sort_children__(node)
  node.dirty_co = false
  if #node.children > 1 then
    local nodemap = self._nodemap ---@type table<string, std.collection.tree.INode>
    local node_sorter = self.node_sorter ---@type std.collection.tree.INodeSorter
    table.sort(node.children, function(left_uuid, right_uuid)
      local left = nodemap[left_uuid] ---@type std.collection.tree.INode
      local right = nodemap[right_uuid] ---@type std.collection.tree.INode
      return node_sorter(left, right)
    end)
  end
end

return M
