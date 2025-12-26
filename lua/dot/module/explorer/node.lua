---@class dot.module.explorer.Node : dot.module.explorer.resource.INode
---@field public uri                    string
---@field public nodename               string
---@field public nodetype               dot.module.explorer.NodeTypeEnum
---@field public parent                 dot.module.explorer.Node|nil
---@field public children               dot.module.explorer.Node[]
---@field public chidxmap               table<string, integer|nil>
---@field public depth                  integer
---@field public loaded                 boolean
---@field public expanded               boolean
---@field public selected               boolean
---@field public has_selected           boolean
local M = {}
M.__index = M

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
---@return dot.module.explorer.Node
function M.clone(node, new_parent)
  ---@type dot.module.explorer.Node
  local cloned = {
    uri = M.calc_uri(new_parent.uri, node.nodename, node.nodetype),
    nodename = node.nodename,
    nodetype = node.nodetype,
    parent = new_parent,
    children = {},
    chidxmap = {},
    depth = new_parent.depth + 1,
    loaded = node.nodetype == "F",
    expanded = false,
    selected = false,
    has_selected = false,
  }

  local self = setmetatable(cloned, M)

  if node.nodetype == "D" and #node.children > 0 then
    for i, child in ipairs(node.children) do
      local cloned_child = M.clone(child, self) ---@type dot.module.explorer.Node
      self.children[i] = cloned_child
      self.chidxmap[cloned_child.nodename] = i
    end
  end

  return self
end

---@param root                          dot.module.explorer.Node
---@return dot.module.explorer.Node[]
function M.collect_selected(root)
  if not root.has_selected and not root.selected then
    return {}
  end

  local result = {} ---@type dot.module.explorer.Node[]

  ---@param node                        dot.module.explorer.Node
  local function traverse(node)
    if node.selected then
      result[#result + 1] = node
    end
    if node.has_selected then
      for _, child in ipairs(node.children) do
        traverse(child)
      end
    end
  end

  traverse(root)
  return result
end

---@param root                          dot.module.explorer.Node
---@return dot.module.explorer.Node[]
function M.collect_selected_toplevel(root)
  if not root.has_selected and not root.selected then
    return {}
  end

  local result = {} ---@type dot.module.explorer.Node[]

  ---@param node                        dot.module.explorer.Node
  local function traverse(node)
    if node.selected then
      result[#result + 1] = node
      return
    end
    if node.has_selected then
      for _, child in ipairs(node.children) do
        traverse(child)
      end
    end
  end

  traverse(root)
  return result
end

---@param root                          dot.module.explorer.Node
---@return string[]
function M.collect_selected_uris(root)
  if not root.has_selected and not root.selected then
    return {}
  end

  local result = {} ---@type string[]

  ---@param node                        dot.module.explorer.Node
  local function traverse(node)
    if node.selected then
      result[#result + 1] = node.uri
    end
    if node.has_selected then
      for _, child in ipairs(node.children) do
        traverse(child)
      end
    end
  end

  traverse(root)
  return result
end

---@param parent                        dot.module.explorer.Node
---@param nodetype                      dot.module.explorer.NodeTypeEnum
---@param nodename                      string
---@return dot.module.explorer.Node
function M.new(parent, nodetype, nodename)
  ---@type dot.module.explorer.Node
  local node = {
    uri = nodetype == "D" and (parent.uri .. nodename .. "/") or (parent.uri .. nodename),
    nodename = nodename,
    nodetype = nodetype,
    parent = parent,
    children = {},
    chidxmap = {},
    depth = parent.depth + 1,
    loaded = nodetype == "F",
    expanded = false,
    selected = false,
    has_selected = false,
  }

  local self = setmetatable(node, M)
  return self
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

---@param protocol                      string
---@return dot.module.explorer.Node
function M.superroot(protocol)
  local nodename = protocol or "file://" ---@type string

  ---@type dot.module.explorer.Node
  local node = {
    uri = nodename .. "/",
    nodename = nodename,
    nodetype = "D",
    parent = nil,
    children = {},
    chidxmap = {},
    depth = 0,
    loaded = false,
    expanded = true,
    selected = false,
    has_selected = false,
  }

  local self = setmetatable(node, M)
  return self
end

--- Check if self is an ancestor of the given node.
--- Note: A node is NOT considered an ancestor of itself.
---@param node                          dot.module.explorer.Node
---@return boolean
function M:is_ancestor_of(node)
  if self.uri == node.uri then
    return false
  end

  local depth = self.depth ---@type integer
  if node.depth <= depth then
    return false
  end

  local o = node.parent ---@type dot.module.explorer.Node|nil
  while o ~= nil and o.depth >= depth do
    if o.uri == self.uri then
      return true
    end
    o = o.parent
  end
  return false
end

--- Check if self is an ancestor of the given node, or if they are the same node.
---@param node                          dot.module.explorer.Node
---@return boolean
function M:is_ancestor_or_self(node)
  if self.uri == node.uri then
    return true
  end

  local depth = self.depth ---@type integer
  if node.depth <= depth then
    return false
  end

  local o = node.parent ---@type dot.module.explorer.Node|nil
  while o ~= nil and o.depth >= depth do
    if o.uri == self.uri then
      return true
    end
    o = o.parent
  end
  return false
end

--- Check if self is a descendant of the given root.
--- Note: A node is NOT considered a descendant of itself.
---@param root                          dot.module.explorer.Node
---@return boolean
function M:is_descendant_of(root)
  if self.uri == root.uri then
    return false
  end

  local depth = root.depth ---@type integer
  if self.depth <= depth then
    return false
  end

  local o = self.parent ---@type dot.module.explorer.Node|nil
  while o ~= nil and o.depth >= depth do
    if o.uri == root.uri then
      return true
    end
    o = o.parent
  end
  return false
end

--- Check if self is a descendant of the given root, or if they are the same node.
---@param root                          dot.module.explorer.Node
---@return boolean
function M:is_descendant_or_self(root)
  if self.uri == root.uri then
    return true
  end

  local depth = root.depth ---@type integer
  if self.depth <= depth then
    return false
  end

  local o = self.parent ---@type dot.module.explorer.Node|nil
  while o ~= nil and o.depth >= depth do
    if o.uri == root.uri then
      return true
    end
    o = o.parent
  end
  return false
end

---@param expanded                      boolean
---@return nil
function M:set_expanded_recursive(expanded)
  self.expanded = expanded
  for _, child in ipairs(self.children) do
    child:set_expanded_recursive(expanded)
  end
end

---@param selected                      boolean
---@return nil
function M:set_selected_recursive(selected)
  self.selected = selected
  if selected then
    self.has_selected = true
  else
    self.has_selected = false
  end
  for _, child in ipairs(self.children) do
    child:set_selected_recursive(selected)
  end
end

--- Sync `has_selected` state from node to its ancestors.
---
--- IMPORTANT: This function assumes `has_selected` propagation is monotonic - once an ancestor
--- has `has_selected = true`, all its ancestors must also have it. The early exit optimization
--- (break when `p.has_selected` is already true) relies on this invariant. Direct modification
--- of `selected` or `has_selected` fields without using `set_selected_recursive` + `sync_ancestors`
--- may violate this invariant and cause incorrect state.
---@param node                          dot.module.explorer.Node
---@return nil
function M.sync_ancestors(node)
  local is_selected = node.selected or node.has_selected ---@type boolean
  local p = node.parent ---@type dot.module.explorer.Node|nil

  while p ~= nil do
    if is_selected then
      -- Early exit: if parent already has_selected, all ancestors above must also have it
      if p.has_selected then
        break
      end
      p.has_selected = true
    else
      if p.selected then
        p.selected = false
      end

      local has_selected = false ---@type boolean
      for _, child in ipairs(p.children) do
        if child.selected or child.has_selected then
          has_selected = true
          break
        end
      end
      -- Early exit: if state unchanged, ancestors above are also unchanged
      if p.has_selected == has_selected then
        break
      end
      p.has_selected = has_selected
    end
    p = p.parent
  end
end

---@param start_idx                     integer
---@return nil
function M:sync_chidxmap(start_idx)
  local children = self.children ---@type dot.module.explorer.Node[]
  local chidxmap = self.chidxmap ---@type table<string, integer|nil>
  for i = start_idx, #children do
    local child = children[i] ---@type dot.module.explorer.Node
    chidxmap[child.nodename] = i
  end
end

return M
