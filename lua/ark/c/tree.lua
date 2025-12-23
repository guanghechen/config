local __module_name__ = "ark.c.tree" ---@type string

---@alias ark.c.ITreeTraverseConditionalEnum
---| "badroot"  -- Don't handle current node and its descendants
---| "goodnode" -- Handle current node, but don't traverse its descendants
---| "goodroot" -- Handle current node and its descendants

---@alias ark.c.ITreeNodeSorter
---| fun(left: ark.c.ITreeNode, right: ark.c.ITreeNode): boolean

---@alias ark.c.ITreeTraverseConditional
---| fun(ctx: ark.c.ITreeTraverseContext, node: ark.c.ITreeNode, cur: integer): ark.c.ITreeTraverseConditionalEnum

---@alias ark.c.ITreeTraverseHandler
---| fun(ctx: ark.c.ITreeTraverseContext, node: ark.c.ITreeNode, cur: integer, is_lastchild: boolean, onlychild: string|nil, childcount: integer): nil

---@alias ark.c.ITreeTraverseRecursive
---| fun(ctx: ark.c.ITreeTraverseContext, node: ark.c.ITreeNode, cur: integer, is_lastchild: boolean): nil

---@alias ark.c.ITreeQuickTraverseHandler
---| fun(ctx: ark.c.ITreeTraverseContext, node: ark.c.ITreeNode, cur: integer): nil

---@alias ark.c.ITreeQuickTraverseRecursive
---| fun(ctx: ark.c.ITreeTraverseContext, node: ark.c.ITreeNode, cur: integer): nil

---@alias ark.c.ITreeUnsafeTraverseCallback
---| fun(ctx: ark.c.ITreeTraverseContext): nil

---@class ark.c.ITreeTraverseContext
---@field public nodemap                table<string, ark.c.ITreeNode>
---@field public rootnode               ark.c.ITreeNode

---@class ark.c.ITreeNode
---@field public uuid                   string
---@field public parent                 string
---@field public children               string[]
---@field public depth                  integer
---@field public data                   table
---@field public dirty_co               boolean children order dirty

----------------------------------------------------------------------------------------------------

---@class ark.c.ITreeProps
---@field public fullname               string|nil
---@field public name                   string
---@field public node_sorter            ark.c.ITreeNodeSorter
---@field public rootnodedata           unknown|nil

---@class ark.c.IReadonlyTree
---@field public fullname               string
---@field public root                   string
---@field public isdisposed             fun(self: ark.c.IReadonlyTree): boolean
---@field public isdescendant           fun(self: ark.c.IReadonlyTree, ancestor: string, uuid: string): boolean
---@field public isexistent             fun(self: ark.c.IReadonlyTree, uuid: string): boolean
---@field public retrieve               fun(self: ark.c.IReadonlyTree, uuid: string): ark.c.ITreeNode|nil
---@field public quick_traverse         fun(self: ark.c.IReadonlyTree, root: string|nil, fn: ark.c.ITreeQuickTraverseHandler, conditional: ark.c.ITreeTraverseConditional|nil): ark.c.IReadonlyTree
---@field public traverse               fun(self: ark.c.IReadonlyTree, root: string|nil, fn: ark.c.ITreeTraverseHandler, conditional: ark.c.ITreeTraverseConditional|nil): ark.c.IReadonlyTree
---@field public unsafe_traverse        fun(self: ark.c.IReadonlyTree, root: string|nil, traverse: ark.c.ITreeUnsafeTraverseCallback): ark.c.IReadonlyTree
---@field public calc_include_uuid_set  fun(self: ark.c.IReadonlyTree, uuids: string[]): table<string, boolean>

---@class ark.c.ITree : ark.c.IReadonlyTree
---@field public fullname               string
---@field public root                   string
---@field public clear                  fun(self: ark.c.ITree): ark.c.ITree
---@field public dispose                fun(self: ark.c.ITree): nil
---@field public isdisposed             fun(self: ark.c.ITree): boolean
---@field public isdescendant           fun(self: ark.c.ITree, ancestor: string, uuid: string): boolean
---@field public isexistent             fun(self: ark.c.ITree, uuid: string): boolean
---@field public retrieve               fun(self: ark.c.ITree, uuid: string): ark.c.ITreeNode|nil
---@field public quick_traverse         fun(self: ark.c.ITree, root: string|nil, fn: ark.c.ITreeQuickTraverseHandler, conditional: ark.c.ITreeTraverseConditional|nil): ark.c.ITree
---@field public traverse               fun(self: ark.c.ITree, root: string|nil, fn: ark.c.ITreeTraverseHandler, conditional: ark.c.ITreeTraverseConditional|nil): ark.c.ITree
---@field public unsafe_traverse        fun(self: ark.c.ITree, root: string|nil, traverse: ark.c.ITreeUnsafeTraverseCallback): ark.c.ITree
---@field public calc_include_uuid_set  fun(self: ark.c.ITree, uuids: string[]): table<string, boolean>
---@field public empty                  fun(self: ark.c.ITree, uuid: string): ark.c.ITree
---@field public insert                 fun(self: ark.c.ITree, parent: string, uuid: string, data: table|nil): ark.c.ITreeNode
---@field public remove                 fun(self: ark.c.ITree, uuid: string): ark.c.ITree

---@class ark.c.Tree : ark.c.ITree
---@field public fullname               string
---@field public root                   string
---@field public node_sorter            ark.c.ITreeNodeSorter
---@field protected _disposed           boolean
---@field protected _nodemap            table<string, ark.c.ITreeNode>
---@field protected _rootnode           ark.c.ITreeNode
local M = {}
M.__index = M

---@param props                         ark.c.ITreeProps
---@return ark.c.Tree
function M.new(props)
  local name = props.name ---@type string
  local fullname = props.fullname or string.format("%s@%s", __module_name__, name) ---@type string
  local node_sorter = props.node_sorter ---@type ark.c.ITreeNodeSorter
  local rootnodedata = props.rootnodedata or {} ---@type unknown
  local uuid_root = "__virtual_root__" ---@type string

  ---@type ark.c.ITreeNode
  local noderoot = {
    uuid = uuid_root,
    parent = uuid_root,
    children = {},
    depth = 0,
    data = rootnodedata,
    dirty_co = false,
  }

  ---@type table<string, ark.c.ITreeNode>
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

---@return ark.c.Tree
function M:clear()
  self:__health__()

  local nodemap = self._nodemap ---@type table<string, ark.c.ITreeNode>
  local rootnode = self._rootnode ---@type ark.c.ITreeNode
  for _, childuuid in ipairs(rootnode.children) do
    local child = nodemap[childuuid] ---@type ark.c.ITreeNode
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

  local nodemap = self._nodemap ---@type table<string, ark.c.ITreeNode>

  local node = nodemap[uuid] ---@type ark.c.ITreeNode|nil
  local node_ancestor = nodemap[ancestor] ---@type ark.c.ITreeNode|nil
  if node == nil or node_ancestor == nil then
    return false
  end

  if node.depth <= node_ancestor.depth then
    return false
  end

  local distance = node.depth - node_ancestor.depth ---@type integer
  for _ = 1, distance, 1 do
    node = nodemap[node.parent] ---@type ark.c.ITreeNode
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
---@return ark.c.ITreeNode|nil
function M:retrieve(uuid)
  self:__health__()
  return self._nodemap[uuid] ---@type ark.c.ITreeNode|nil
end

---@param root                          string
---@param fn                            ark.c.ITreeQuickTraverseHandler
---@param conditional                   ?ark.c.ITreeTraverseConditional
---@return ark.c.Tree
function M:quick_traverse(root, fn, conditional)
  self:__health__()

  local nodemap = self._nodemap ---@type table<string, ark.c.ITreeNode>
  local recursive ---@type ark.c.ITreeQuickTraverseRecursive
  local rootnode = root and nodemap[root] or self._rootnode ---@type ark.c.ITreeNode

  if conditional == nil then
    ---@type ark.c.ITreeQuickTraverseRecursive
    recursive = function(ctx, node, cur)
      fn(ctx, node, cur)

      if node.dirty_co then
        self:__sort_children__(node)
      end

      local next_cur = cur + 1 ---@type integer
      local N = #node.children ---@type integer
      for index = 1, N, 1 do
        local childuuid = node.children[index] ---@type string
        local child = nodemap[childuuid] ---@type ark.c.ITreeNode
        recursive(ctx, child, next_cur)
      end
    end
  else
    ---@type ark.c.ITreeQuickTraverseRecursive
    recursive = function(ctx, node, cur)
      local condition = conditional(ctx, node, cur) ---@type ark.c.ITreeTraverseConditionalEnum
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
        local child = nodemap[childuuid] ---@type ark.c.ITreeNode
        recursive(ctx, child, next_cur)
      end
    end
  end

  if rootnode == self._rootnode then
    if rootnode.dirty_co then
      self:__sort_children__(rootnode)
    end

    for _, childuuid in ipairs(rootnode.children) do
      local childnode = nodemap[childuuid] ---@type ark.c.ITreeNode
      local ctx = { nodemap = nodemap, rootnode = childnode } ---@type ark.c.ITreeTraverseContext
      recursive(ctx, childnode, 1)
    end
  else
    local ctx = { nodemap = nodemap, rootnode = rootnode } ---@type ark.c.ITreeTraverseContext
    recursive(ctx, rootnode, 1)
  end

  return self
end

---@param root                          string
---@param fn                            ark.c.ITreeTraverseHandler
---@param conditional                   ?ark.c.ITreeTraverseConditional
---@return ark.c.Tree
function M:traverse(root, fn, conditional)
  self:__health__()

  local nodemap = self._nodemap ---@type table<string, ark.c.ITreeNode>
  local recursive ---@type ark.c.ITreeTraverseRecursive

  if conditional == nil then
    ---@type ark.c.ITreeTraverseRecursive
    recursive = function(ctx, node, cur, is_lastchild)
      local N = #node.children ---@type integer
      local next_cur = cur + 1 ---@type integer

      if N == 0 then
        fn(ctx, node, cur, is_lastchild, nil, N)
        return
      end

      if N == 1 then
        local childuuid = node.children[1] ---@type string
        local childnode = nodemap[childuuid] ---@type ark.c.ITreeNode
        fn(ctx, node, cur, is_lastchild, childuuid, N)
        return recursive(ctx, childnode, next_cur, true)
      end

      fn(ctx, node, cur, is_lastchild, nil, N)

      if node.dirty_co then
        self:__sort_children__(node)
      end

      for index = 1, N, 1 do
        local childuuid = node.children[index] ---@type string
        local child = nodemap[childuuid] ---@type ark.c.ITreeNode
        recursive(ctx, child, next_cur, index == N)
      end
    end
  else
    ---@type ark.c.ITreeTraverseRecursive
    recursive = function(ctx, node, cur, is_lastchild)
      local condition = conditional(ctx, node, cur) ---@type ark.c.ITreeTraverseConditionalEnum
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
        local child = nodemap[childuuid] ---@type ark.c.ITreeNode
        local child_condition = conditional(ctx, child, next_cur) ---@type ark.c.ITreeTraverseConditionalEnum
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
        local childnode = nodemap[childuuid] ---@type ark.c.ITreeNode
        fn(ctx, node, cur, is_lastchild, childuuid, N)
        return recursive(ctx, childnode, next_cur, true)
      end

      fn(ctx, node, cur, is_lastchild, nil, N)

      for index = first_child_index, last_child_index, 1 do
        local childuuid = node.children[index] ---@type string
        local childnode = nodemap[childuuid] ---@type ark.c.ITreeNode
        recursive(ctx, childnode, next_cur, index == last_child_index)
      end
    end
  end

  local rootnode = nodemap[root] or self._rootnode ---@type ark.c.ITreeNode
  if rootnode == self._rootnode then
    if rootnode.dirty_co then
      self:__sort_children__(rootnode)
    end

    for _, childuuid in ipairs(rootnode.children) do
      local childnode = nodemap[childuuid] ---@type ark.c.ITreeNode
      local ctx = { nodemap = nodemap, rootnode = childnode } ---@type ark.c.ITreeTraverseContext
      recursive(ctx, childnode, 1, true)
    end
  else
    local ctx = { nodemap = nodemap, rootnode = rootnode } ---@type ark.c.ITreeTraverseContext
    recursive(ctx, rootnode, 1, true)
  end

  return self
end

---@param root                          string|nil
---@param traverse                      ark.c.ITreeUnsafeTraverseCallback
---@return ark.c.Tree
function M:unsafe_traverse(root, traverse)
  self:__health__()
  local nodemap = self._nodemap ---@type table<string, ark.c.ITreeNode>

  local rootnode = nodemap[root] or self._rootnode ---@type ark.c.ITreeNode
  if rootnode == self._rootnode then
    if rootnode.dirty_co then
      self:__sort_children__(rootnode)
    end

    for _, childuuid in ipairs(rootnode.children) do
      local childnode = nodemap[childuuid] ---@type ark.c.ITreeNode
      local ctx = { nodemap = nodemap, rootnode = childnode } ---@type ark.c.ITreeTraverseContext
      traverse(ctx)
    end
  else
    local ctx = { nodemap = nodemap, rootnode = rootnode } ---@type ark.c.ITreeTraverseContext
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
  local nodemap = self._nodemap ---@type table<string, ark.c.ITreeNode>
  local N = #uuids ---@type integer
  for index = 1, N, 1 do
    local uuid = uuids[index] ---@type string
    while uuid ~= nil and not uuidset[uuid] do
      local node = nodemap[uuid] ---@type ark.c.ITreeNode|nil
      if node == nil then
        ark.reporter.warn({
          from = self.fullname,
          subject = "calc_include_uuid_set",
          message = string.format("Unknown node uuid: %s", uuid),
        })
        break
      end

      uuidset[uuid] = true
      uuid = node.parent ---@type string
    end
  end
  return uuidset
end

---@param uuid                          string
---@return ark.c.Tree
function M:empty(uuid)
  self:__health__()

  local rootnode = self._rootnode ---@type ark.c.ITreeNode
  if uuid == rootnode.uuid then
    return self:clear()
  end

  local nodemap = self._nodemap ---@type table<string, ark.c.ITreeNode>
  local node = nodemap[uuid] ---@type ark.c.ITreeNode|nil
  if node == nil then
    ark.reporter.error({
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
    local childnode = nodemap[childuuid] ---@type ark.c.ITreeNode
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
---@return ark.c.ITreeNode
function M:insert(parent, uuid, data)
  self:__health__()

  local nodemap = self._nodemap ---@type table<string, ark.c.ITreeNode>
  local node = nodemap[uuid] ---@type ark.c.ITreeNode|nil

  local node_parent = parent ~= uuid and nodemap[parent] or self._rootnode ---@type ark.c.ITreeNode
  parent = node_parent.uuid ---@type string

  if node == nil then
    ---@type ark.c.ITreeNode
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

    local old_node_parent = nodemap[node.parent] ---@type ark.c.ITreeNode
    ark.table.filter_inline(old_node_parent.children, function(childuuid)
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

  local nodemap = self._nodemap ---@type table<string, ark.c.ITreeNode>
  local rootnode = rootuuid and nodemap[rootuuid] or self._rootnode ---@type ark.c.ITreeNode
  local lines = {} ---@type string[]

  ---@param node                        ark.c.ITreeNode
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
      local child = nodemap[childuuid] ---@type ark.c.ITreeNode
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
---@return ark.c.Tree
function M:remove(nodeuuid)
  self:__health__()

  local rootnode = self._rootnode ---@type ark.c.ITreeNode
  if nodeuuid == rootnode.uuid then
    return self:clear()
  end

  local nodemap = self._nodemap ---@type table<string, ark.c.ITreeNode>
  local node = nodemap[nodeuuid] ---@type ark.c.ITreeNode|nil
  if node == nil then
    ark.reporter.error({
      from = self.fullname,
      subject = "remove",
      message = string.format("Node with uuid '%s' does not exist.", nodeuuid),
      details = {
        uuid = nodeuuid,
      },
    })
    return self
  end

  local node_parent = nodemap[node.parent] ---@type ark.c.ITreeNode

  self:__remove_recursive__(node)
  ark.table.filter_inline(node_parent.children, function(childuuid)
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
---@param node                          ark.c.ITreeNode
---@return nil
function M:__remove_recursive__(node)
  local nodemap = self._nodemap ---@type table<string, ark.c.ITreeNode>
  for _, childuuid in ipairs(node.children) do
    local child = nodemap[childuuid] ---@type ark.c.ITreeNode|nil
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
---@param node                          ark.c.ITreeNode
---@param depth                         integer
---@return nil
function M:__resolve_depth_recursive__(node, depth)
  node.depth = depth
  for _, childuuid in ipairs(node.children) do
    local child = self._nodemap[childuuid] ---@type ark.c.ITreeNode
    self:__resolve_depth_recursive__(child, depth + 1)
  end
end

---@protected
---@param node                          ark.c.ITreeNode
---@return nil
function M:__sort_children__(node)
  node.dirty_co = false
  if #node.children > 1 then
    local nodemap = self._nodemap ---@type table<string, ark.c.ITreeNode>
    local node_sorter = self.node_sorter ---@type ark.c.ITreeNodeSorter
    table.sort(node.children, function(left_uuid, right_uuid)
      local left = nodemap[left_uuid] ---@type ark.c.ITreeNode
      local right = nodemap[right_uuid] ---@type ark.c.ITreeNode
      return node_sorter(left, right)
    end)
  end
end

return M
