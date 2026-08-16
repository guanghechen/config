---@diagnostic disable-next-line: unused-local
local __module_name__ = "stl.c.tree" ---@type string

---@alias stl.c.ITreeTraverseConditionalEnum
---| "badroot"  -- Don't handle current node and its descendants
---| "goodnode" -- Handle current node, but don't traverse its descendants
---| "goodroot" -- Handle current node and its descendants

---@alias stl.c.ITreeNodeSorter
---| fun(left: stl.c.ITreeNode, right: stl.c.ITreeNode): boolean

---@alias stl.c.ITreeTraverseConditional
---| fun(ctx: stl.c.ITreeTraverseContext, node: stl.c.ITreeNode, cur: integer): stl.c.ITreeTraverseConditionalEnum

---@alias stl.c.ITreeTraverseHandler
---| fun(ctx: stl.c.ITreeTraverseContext, node: stl.c.ITreeNode, cur: integer, is_lastchild: boolean, onlychild: string|nil, childcount: integer): nil

---@alias stl.c.ITreeTraverseRecursive
---| fun(ctx: stl.c.ITreeTraverseContext, node: stl.c.ITreeNode, cur: integer, is_lastchild: boolean): nil

---@alias stl.c.ITreeQuickTraverseHandler
---| fun(ctx: stl.c.ITreeTraverseContext, node: stl.c.ITreeNode, cur: integer): nil

---@alias stl.c.ITreeQuickTraverseRecursive
---| fun(ctx: stl.c.ITreeTraverseContext, node: stl.c.ITreeNode, cur: integer): nil

---@alias stl.c.ITreeUnsafeTraverseCallback
---| fun(ctx: stl.c.ITreeTraverseContext): nil

---@class stl.c.ITreeTraverseContext
---@field public nodemap                table<string, stl.c.ITreeNode>
---@field public rootnode               stl.c.ITreeNode

---@class stl.c.ITreeNode
---@field public uuid                   string
---@field public parent                 string
---@field public children               string[]
---@field public depth                  integer
---@field public data                   table
---@field public dirty_co               boolean children order dirty

----------------------------------------------------------------------------------------------------

---@class stl.c.ITreeProps
---@field public fullname               string|nil
---@field public name                   string
---@field public node_sorter            stl.c.ITreeNodeSorter
---@field public rootnodedata           unknown|nil

---@class stl.c.IReadonlyTree
---@field public fullname               string
---@field public root                   string
---@field public isdisposed             fun(self: stl.c.IReadonlyTree): boolean
---@field public isdescendant           fun(self: stl.c.IReadonlyTree, ancestor: string, uuid: string): boolean
---@field public isexistent             fun(self: stl.c.IReadonlyTree, uuid: string): boolean
---@field public retrieve               fun(self: stl.c.IReadonlyTree, uuid: string): stl.c.ITreeNode|nil
---@field public get                    fun(self: stl.c.IReadonlyTree, uuid: string): unknown|nil
---@field public contains               fun(self: stl.c.IReadonlyTree, uuid: string): boolean
---@field public parent                 fun(self: stl.c.IReadonlyTree, uuid: string): string|nil
---@field public children               fun(self: stl.c.IReadonlyTree, uuid: string): string[]|nil
---@field public quick_traverse         fun(self: stl.c.IReadonlyTree, root: string|nil, fn: stl.c.ITreeQuickTraverseHandler, conditional: stl.c.ITreeTraverseConditional|nil): stl.c.IReadonlyTree
---@field public traverse               fun(self: stl.c.IReadonlyTree, root: string|nil, fn: stl.c.ITreeTraverseHandler, conditional: stl.c.ITreeTraverseConditional|nil): stl.c.IReadonlyTree
---@field public unsafe_traverse        fun(self: stl.c.IReadonlyTree, root: string|nil, traverse: stl.c.ITreeUnsafeTraverseCallback): stl.c.IReadonlyTree
---@field public calc_include_uuid_set  fun(self: stl.c.IReadonlyTree, uuids: string[]): table<string, boolean>

---@class stl.c.ITree : stl.c.IReadonlyTree
---@field public fullname               string
---@field public root                   string
---@field public clear                  fun(self: stl.c.ITree): stl.c.ITree
---@field public dispose                fun(self: stl.c.ITree): nil
---@field public isdisposed             fun(self: stl.c.ITree): boolean
---@field public isdescendant           fun(self: stl.c.ITree, ancestor: string, uuid: string): boolean
---@field public isexistent             fun(self: stl.c.ITree, uuid: string): boolean
---@field public retrieve               fun(self: stl.c.ITree, uuid: string): stl.c.ITreeNode|nil
---@field public get                    fun(self: stl.c.ITree, uuid: string): unknown|nil
---@field public contains               fun(self: stl.c.ITree, uuid: string): boolean
---@field public parent                 fun(self: stl.c.ITree, uuid: string): string|nil
---@field public children               fun(self: stl.c.ITree, uuid: string): string[]|nil
---@field public quick_traverse         fun(self: stl.c.ITree, root: string|nil, fn: stl.c.ITreeQuickTraverseHandler, conditional: stl.c.ITreeTraverseConditional|nil): stl.c.ITree
---@field public traverse               fun(self: stl.c.ITree, root: string|nil, fn: stl.c.ITreeTraverseHandler, conditional: stl.c.ITreeTraverseConditional|nil): stl.c.ITree
---@field public unsafe_traverse        fun(self: stl.c.ITree, root: string|nil, traverse: stl.c.ITreeUnsafeTraverseCallback): stl.c.ITree
---@field public calc_include_uuid_set  fun(self: stl.c.ITree, uuids: string[]): table<string, boolean>
---@field public empty                  fun(self: stl.c.ITree, uuid: string): stl.c.ITree
---@field public insert                 fun(self: stl.c.ITree, parent: string, uuid: string, data: table|nil, index?: integer): stl.c.ITreeNode
---@field public update                 fun(self: stl.c.ITree, uuid: string, data: table): stl.c.ITreeNode
---@field public move                   fun(self: stl.c.ITree, uuid: string, parent: string, index?: integer): stl.c.ITreeNode
---@field public remove                 fun(self: stl.c.ITree, uuid: string): stl.c.ITree

---@class stl.c.Tree : stl.c.ITree
---@field public fullname               string
---@field public root                   string
---@field public node_sorter            stl.c.ITreeNodeSorter|nil
---@field protected _disposed           boolean
---@field protected _strict_mutations   boolean
---@field protected _nodemap            table<string, stl.c.ITreeNode>
---@field protected _rootnode           stl.c.ITreeNode
local M = {}
M.__index = M

---@overload fun(root: string, rootdata?: table): stl.c.Tree
---@param props                         stl.c.ITreeProps|string
---@param rootdata?                     table
---@return stl.c.Tree
function M.new(props, rootdata)
  if type(props) ~= "string" and type(props) ~= "table" then
    error(string.format("[%s] root or props must be a string or table", __module_name__), 2)
  end
  local strict_mutations = type(props) == "string" ---@type boolean
  local uuid_root ---@type string
  local fullname ---@type string
  local node_sorter ---@type stl.c.ITreeNodeSorter|nil
  local rootnodedata ---@type unknown
  if strict_mutations then
    uuid_root = props ---@type string
    fullname = string.format("%s@%s", __module_name__, uuid_root)
    rootnodedata = rootdata ~= nil and rootdata or {}
  else
    ---@cast props                      stl.c.ITreeProps
    local name = props.name ---@type string
    fullname = props.fullname or string.format("%s@%s", __module_name__, name)
    node_sorter = props.node_sorter
    rootnodedata = props.rootnodedata or {}
    uuid_root = "__virtual_root__"
  end

  ---@type stl.c.ITreeNode
  local noderoot = {
    uuid = uuid_root,
    parent = uuid_root,
    children = {},
    depth = 0,
    data = rootnodedata,
    dirty_co = false,
  }

  ---@type table<string, stl.c.ITreeNode>
  local nodemap = {
    [uuid_root] = noderoot,
  }

  local self = setmetatable({}, M)
  self.fullname = fullname
  self.root = uuid_root
  self.node_sorter = node_sorter
  self._disposed = false
  self._strict_mutations = strict_mutations
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
  self.node_sorter = nil
  self._strict_mutations = nil
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
---@return boolean
function M:isexistent(uuid)
  self:__health__()
  return self._nodemap[uuid] ~= nil
end

---@param uuid                          string
---@return stl.c.ITreeNode|nil
function M:retrieve(uuid)
  self:__health__()
  return self._nodemap[uuid] ---@type stl.c.ITreeNode|nil
end

---@param uuid                          string
---@return unknown|nil
function M:get(uuid)
  local node = self:retrieve(uuid)
  return node ~= nil and node.data or nil
end

---@param uuid                          string
---@return boolean
function M:contains(uuid)
  return self:isexistent(uuid)
end

---@param uuid                          string
---@return string|nil
function M:parent(uuid)
  local node = self:retrieve(uuid)
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
---@return stl.c.ITreeNode
function M:update(uuid, data)
  self:__health__()
  local node = self._nodemap[uuid] ---@type stl.c.ITreeNode|nil
  if node == nil then
    error(string.format("[%s] node '%s' does not exist", __module_name__, uuid), 2)
  end
  node.data = data
  return node
end

---@param uuid                          string
---@param parent                        string
---@param index?                        integer
---@return stl.c.ITreeNode
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
    return node
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
  return node
end

---@param root                          string
---@param fn                            stl.c.ITreeQuickTraverseHandler
---@param conditional                   ?stl.c.ITreeTraverseConditional
---@return stl.c.Tree
function M:quick_traverse(root, fn, conditional)
  self:__health__()

  local nodemap = self._nodemap ---@type table<string, stl.c.ITreeNode>
  local recursive ---@type stl.c.ITreeQuickTraverseRecursive
  local rootnode = root and nodemap[root] or self._rootnode ---@type stl.c.ITreeNode

  if conditional == nil then
    ---@type stl.c.ITreeQuickTraverseRecursive
    recursive = function(ctx, node, cur)
      fn(ctx, node, cur)

      if node.dirty_co then
        self:__sort_children__(node)
      end

      local next_cur = cur + 1 ---@type integer
      local N = #node.children ---@type integer
      for index = 1, N, 1 do
        local childuuid = node.children[index] ---@type string
        local child = nodemap[childuuid] ---@type stl.c.ITreeNode
        recursive(ctx, child, next_cur)
      end
    end
  else
    ---@type stl.c.ITreeQuickTraverseRecursive
    recursive = function(ctx, node, cur)
      local condition = conditional(ctx, node, cur) ---@type stl.c.ITreeTraverseConditionalEnum
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
        local child = nodemap[childuuid] ---@type stl.c.ITreeNode
        recursive(ctx, child, next_cur)
      end
    end
  end

  if rootnode == self._rootnode then
    if rootnode.dirty_co then
      self:__sort_children__(rootnode)
    end

    for _, childuuid in ipairs(rootnode.children) do
      local childnode = nodemap[childuuid] ---@type stl.c.ITreeNode
      local ctx = { nodemap = nodemap, rootnode = childnode } ---@type stl.c.ITreeTraverseContext
      recursive(ctx, childnode, 1)
    end
  else
    local ctx = { nodemap = nodemap, rootnode = rootnode } ---@type stl.c.ITreeTraverseContext
    recursive(ctx, rootnode, 1)
  end

  return self
end

---@param root                          string
---@param fn                            stl.c.ITreeTraverseHandler
---@param conditional                   ?stl.c.ITreeTraverseConditional
---@return stl.c.Tree
function M:traverse(root, fn, conditional)
  self:__health__()

  local nodemap = self._nodemap ---@type table<string, stl.c.ITreeNode>
  local recursive ---@type stl.c.ITreeTraverseRecursive

  if conditional == nil then
    ---@type stl.c.ITreeTraverseRecursive
    recursive = function(ctx, node, cur, is_lastchild)
      local N = #node.children ---@type integer
      local next_cur = cur + 1 ---@type integer

      if N == 0 then
        fn(ctx, node, cur, is_lastchild, nil, N)
        return
      end

      if N == 1 then
        local childuuid = node.children[1] ---@type string
        local childnode = nodemap[childuuid] ---@type stl.c.ITreeNode
        fn(ctx, node, cur, is_lastchild, childuuid, N)
        return recursive(ctx, childnode, next_cur, true)
      end

      fn(ctx, node, cur, is_lastchild, nil, N)

      if node.dirty_co then
        self:__sort_children__(node)
      end

      for index = 1, N, 1 do
        local childuuid = node.children[index] ---@type string
        local child = nodemap[childuuid] ---@type stl.c.ITreeNode
        recursive(ctx, child, next_cur, index == N)
      end
    end
  else
    ---@type stl.c.ITreeTraverseRecursive
    recursive = function(ctx, node, cur, is_lastchild)
      local condition = conditional(ctx, node, cur) ---@type stl.c.ITreeTraverseConditionalEnum
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
        local child = nodemap[childuuid] ---@type stl.c.ITreeNode
        local child_condition = conditional(ctx, child, next_cur) ---@type stl.c.ITreeTraverseConditionalEnum
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
        local childnode = nodemap[childuuid] ---@type stl.c.ITreeNode
        fn(ctx, node, cur, is_lastchild, childuuid, N)
        return recursive(ctx, childnode, next_cur, true)
      end

      fn(ctx, node, cur, is_lastchild, nil, N)

      for index = first_child_index, last_child_index, 1 do
        local childuuid = node.children[index] ---@type string
        local childnode = nodemap[childuuid] ---@type stl.c.ITreeNode
        recursive(ctx, childnode, next_cur, index == last_child_index)
      end
    end
  end

  local rootnode = nodemap[root] or self._rootnode ---@type stl.c.ITreeNode
  if rootnode == self._rootnode then
    if rootnode.dirty_co then
      self:__sort_children__(rootnode)
    end

    for _, childuuid in ipairs(rootnode.children) do
      local childnode = nodemap[childuuid] ---@type stl.c.ITreeNode
      local ctx = { nodemap = nodemap, rootnode = childnode } ---@type stl.c.ITreeTraverseContext
      recursive(ctx, childnode, 1, true)
    end
  else
    local ctx = { nodemap = nodemap, rootnode = rootnode } ---@type stl.c.ITreeTraverseContext
    recursive(ctx, rootnode, 1, true)
  end

  return self
end

---@param root                          string|nil
---@param traverse                      stl.c.ITreeUnsafeTraverseCallback
---@return stl.c.Tree
function M:unsafe_traverse(root, traverse)
  self:__health__()
  local nodemap = self._nodemap ---@type table<string, stl.c.ITreeNode>

  local rootnode = nodemap[root] or self._rootnode ---@type stl.c.ITreeNode
  if rootnode == self._rootnode then
    if rootnode.dirty_co then
      self:__sort_children__(rootnode)
    end

    for _, childuuid in ipairs(rootnode.children) do
      local childnode = nodemap[childuuid] ---@type stl.c.ITreeNode
      local ctx = { nodemap = nodemap, rootnode = childnode } ---@type stl.c.ITreeTraverseContext
      traverse(ctx)
    end
  else
    local ctx = { nodemap = nodemap, rootnode = rootnode } ---@type stl.c.ITreeTraverseContext
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
  local nodemap = self._nodemap ---@type table<string, stl.c.ITreeNode>
  local N = #uuids ---@type integer
  for index = 1, N, 1 do
    local uuid = uuids[index] ---@type string
    while uuid ~= nil and not uuidset[uuid] do
      local node = nodemap[uuid] ---@type stl.c.ITreeNode|nil
      if node == nil then
        stl.reporter.warn({
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
---@return stl.c.Tree
function M:empty(uuid)
  self:__health__()

  local rootnode = self._rootnode ---@type stl.c.ITreeNode
  if uuid == rootnode.uuid then
    return self:clear()
  end

  local nodemap = self._nodemap ---@type table<string, stl.c.ITreeNode>
  local node = nodemap[uuid] ---@type stl.c.ITreeNode|nil
  if node == nil then
    stl.reporter.error({
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
    local childnode = nodemap[childuuid] ---@type stl.c.ITreeNode
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
---@param index?                        integer
---@return stl.c.ITreeNode
function M:insert(parent, uuid, data, index)
  self:__health__()

  local nodemap = self._nodemap ---@type table<string, stl.c.ITreeNode>
  local node = nodemap[uuid] ---@type stl.c.ITreeNode|nil

  if self._strict_mutations then
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
    return node
  end

  local node_parent = parent ~= uuid and nodemap[parent] or self._rootnode ---@type stl.c.ITreeNode
  parent = node_parent.uuid ---@type string

  if node == nil then
    ---@type stl.c.ITreeNode
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

    local old_node_parent = nodemap[node.parent] ---@type stl.c.ITreeNode
    stl.table.filter_inline(old_node_parent.children, function(childuuid)
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

  local nodemap = self._nodemap ---@type table<string, stl.c.ITreeNode>
  local rootnode = rootuuid and nodemap[rootuuid] or self._rootnode ---@type stl.c.ITreeNode
  local lines = {} ---@type string[]

  ---@param node                        stl.c.ITreeNode
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
      local child = nodemap[childuuid] ---@type stl.c.ITreeNode
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
---@return stl.c.Tree
function M:remove(nodeuuid)
  self:__health__()

  local rootnode = self._rootnode ---@type stl.c.ITreeNode
  if nodeuuid == rootnode.uuid then
    if self._strict_mutations then
      error(string.format("[%s] root cannot be removed", __module_name__), 2)
    end
    return self:clear()
  end

  local nodemap = self._nodemap ---@type table<string, stl.c.ITreeNode>
  local node = nodemap[nodeuuid] ---@type stl.c.ITreeNode|nil
  if node == nil then
    if self._strict_mutations then
      error(string.format("[%s] node '%s' does not exist", __module_name__, nodeuuid), 2)
    end
    stl.reporter.error({
      from = self.fullname,
      subject = "remove",
      message = string.format("Node with uuid '%s' does not exist.", nodeuuid),
      details = {
        uuid = nodeuuid,
      },
    })
    return self
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
  if #node.children > 1 then
    local nodemap = self._nodemap ---@type table<string, stl.c.ITreeNode>
    local node_sorter = self.node_sorter ---@type stl.c.ITreeNodeSorter
    table.sort(node.children, function(left_uuid, right_uuid)
      local left = nodemap[left_uuid] ---@type stl.c.ITreeNode
      local right = nodemap[right_uuid] ---@type stl.c.ITreeNode
      return node_sorter(left, right)
    end)
  end
end

return M
