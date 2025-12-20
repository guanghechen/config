---@class dot.module.explorer.Node : dot.module.explorer.resource.INode
---@field public parent                 dot.module.explorer.Node|nil
---@field public children               dot.module.explorer.Node[]
---@field public chidxmap               table<string, integer|nil>
---@field public depth                  integer
---@field public rs                     dot.module.explorer.node.IRootState
---@field public ns                     dot.module.explorer.node.INodeState
local M = {}
M.__index = M

---@param parent                        dot.module.explorer.Node
---@param nodetype                      dot.module.explorer.NodeTypeEnum
---@param nodename                      string
---@param tick_expanded_even            integer
---@return dot.module.explorer.Node
function M.new(parent, nodetype, nodename, tick_expanded_even)
  ---@type dot.module.explorer.node.IRootState
  local rs = {
    tick_expanded = parent.rs.tick_expanded,
    tick_selected = parent.rs.tick_selected,
  }

  ---@type dot.module.explorer.node.INodeState
  local ns = {
    tick_expanded = tick_expanded_even,
    tick_loaded = nodetype == "F" and 1 or 0,
  }

  ---@type dot.module.explorer.Node
  local node = {
    uri = nodetype == "D" and (parent.uri .. nodename .. "/") or (parent.uri .. nodename),
    nodetype = nodetype,
    nodename = nodename,
    parent = parent,
    children = {},
    chidxmap = {},
    depth = parent.depth + 1,
    rs = rs,
    ns = ns,
  }

  local self = setmetatable(node, M)
  return self
end

---@param protocol                      string
---@param tick_expanded_odd             integer
---@return dot.module.explorer.Node
function M.superroot(protocol, tick_expanded_odd)
  local nodename = protocol or "file://" ---@type string

  ---@type dot.module.explorer.node.IRootState
  local rs = {
    tick_expanded = 0,
    tick_selected = 0,
  }

  ---@type dot.module.explorer.node.INodeState
  local ns = {
    tick_expanded = tick_expanded_odd,
    tick_loaded = 0,
  }

  ---@type dot.module.explorer.Node
  local node = {
    uri = nodename .. "/",
    nodetype = "D",
    nodename = nodename,
    parent = nil,
    children = {},
    chidxmap = {},
    depth = 0,
    rs = rs,
    ns = ns,
  }

  local self = setmetatable(node, M)
  return self
end

---@param parent_uri                    string
---@param nodename                      string
---@param nodetype                      dot.module.explorer.NodeTypeEnum
---@return string
function M.calc_uri(parent_uri, nodename, nodetype)
  if nodetype == "D" then
    return parent_uri .. nodename .. "/"
  else
    return parent_uri .. nodename
  end
end

---@param node                          dot.module.explorer.Node
---@param new_parent                    dot.module.explorer.Node
---@param tick_expanded_even            integer
---@return dot.module.explorer.Node
function M.clone(node, new_parent, tick_expanded_even)
  ---@type dot.module.explorer.node.IRootState
  local rs = {
    tick_expanded = new_parent.rs.tick_expanded,
    tick_selected = new_parent.rs.tick_selected,
  }

  ---@type dot.module.explorer.node.INodeState
  local ns = {
    tick_expanded = tick_expanded_even,
    tick_loaded = node.nodetype == "F" and 1 or 0,
  }

  ---@type dot.module.explorer.Node
  local cloned = {
    uri = M.calc_uri(new_parent.uri, node.nodename, node.nodetype),
    nodetype = node.nodetype,
    nodename = node.nodename,
    parent = new_parent,
    children = {},
    chidxmap = {},
    depth = new_parent.depth + 1,
    rs = rs,
    ns = ns,
  }

  local self = setmetatable(cloned, M)

  if node.nodetype == "D" and #node.children > 0 then
    for i, child in ipairs(node.children) do
      local cloned_child = M.clone(child, self, tick_expanded_even) ---@type dot.module.explorer.Node
      self.children[i] = cloned_child
      self.chidxmap[cloned_child.nodename] = i
    end
  end

  return self
end

---@param parent                        dot.module.explorer.Node
---@param start_idx                     integer
---@return nil
function M.sync_chidxmap(parent, start_idx)
  local children = parent.children ---@type dot.module.explorer.Node[]
  local chidxmap = parent.chidxmap ---@type table<string, integer|nil>
  for i = start_idx, #children do
    local child = children[i] ---@type dot.module.explorer.Node
    chidxmap[child.nodename] = i
  end
end

---@param node                          dot.module.explorer.Node
---@param new_depth                     integer
---@return nil
function M.refresh_depth(node, new_depth)
  node.depth = new_depth
  for _, child in ipairs(node.children) do
    M.refresh_depth(child, new_depth + 1)
  end
end

----------------------------------------------------------------------------------------------------
--- Tick-based state queries
----------------------------------------------------------------------------------------------------

---@param tick_loaded                   integer
---@return boolean
function M:is_loaded(tick_loaded)
  return self.ns.tick_loaded == tick_loaded
end

---@return boolean
function M:is_expanded()
  local max_tick = self.ns.tick_expanded ---@type integer
  local o = self ---@type dot.module.explorer.Node|nil
  while o ~= nil do
    max_tick = math.max(max_tick, o.rs.tick_expanded)
    o = o.parent
  end
  return max_tick % 2 == 1
end

---@return boolean
function M:is_selected()
  local max_tick = 0 ---@type integer
  local o = self ---@type dot.module.explorer.Node|nil
  while o ~= nil do
    max_tick = math.max(max_tick, o.rs.tick_selected)
    o = o.parent
  end
  return max_tick % 2 == 1
end

----------------------------------------------------------------------------------------------------
--- Tick-based state mutations
----------------------------------------------------------------------------------------------------

---@param tick_loaded                   integer
---@return nil
function M:mark_loaded(tick_loaded)
  self.ns.tick_loaded = tick_loaded
end

---@param tick_expanded                 integer
---@param recursive                     boolean
---@return nil
function M:set_expanded(tick_expanded, recursive)
  if recursive then
    self.rs.tick_expanded = tick_expanded
  else
    self.ns.tick_expanded = tick_expanded
  end
end

---@param tick_selected                 integer
---@return nil
function M:set_selected(tick_selected)
  self.rs.tick_selected = tick_selected
end

----------------------------------------------------------------------------------------------------
--- Collection helpers
----------------------------------------------------------------------------------------------------

---@param root                          dot.module.explorer.Node
---@return dot.module.explorer.Node[]
function M.collect_selected(root)
  local result = {} ---@type dot.module.explorer.Node[]

  ---@param node                        dot.module.explorer.Node
  local function traverse(node)
    if node:is_selected() then
      result[#result + 1] = node
    end
    for _, child in ipairs(node.children) do
      traverse(child)
    end
  end

  traverse(root)
  return result
end

---@param root                          dot.module.explorer.Node
---@return string[]
function M.collect_selected_uris(root)
  local result = {} ---@type string[]

  ---@param node                        dot.module.explorer.Node
  local function traverse(node)
    if node:is_selected() then
      result[#result + 1] = node.uri
    end
    for _, child in ipairs(node.children) do
      traverse(child)
    end
  end

  traverse(root)
  return result
end

----------------------------------------------------------------------------------------------------
--- Ancestor/Descendant checks
----------------------------------------------------------------------------------------------------

---@param node                          dot.module.explorer.Node
---@return boolean
function M:is_ancestor_of(node)
  local uri = self.uri ---@type string
  if node.uri == uri then
    return true
  end

  local depth = self.depth ---@type integer
  if node.depth <= depth then
    return false
  end

  local o = node.parent ---@type dot.module.explorer.Node|nil
  while o ~= nil and depth <= o.depth do
    if o.uri == uri then
      return true
    end
    o = o.parent
  end
  return false
end

---@param root                          dot.module.explorer.Node
---@return boolean
function M:is_descendant_of(root)
  local uri = root.uri ---@type string
  if self.uri == uri then
    return true
  end

  local depth = root.depth ---@type integer
  if self.depth <= depth then
    return false
  end

  local o = self.parent ---@type dot.module.explorer.Node|nil
  while o ~= nil and o.depth >= depth do
    if o.uri == uri then
      return true
    end
    o = o.parent
  end
  return false
end

return M
