---@class era.m.explorer.Node : era.m.explorer.resource.INode
---@field public filepath               string
---@field public nodename               string
---@field public nodetype               era.m.explorer.NodeTypeEnum
---@field public parent                 era.m.explorer.Node|nil
---@field public children               era.m.explorer.Node[]
---@field public chidxmap               table<string, integer|nil>
---@field public depth                  integer
---@field public loaded                 boolean
---@field public expanded               boolean
---@field public selected               boolean
---@field public has_selected           boolean
local M = {}
M.__index = M

---@param parent_filepath               string
---@param nodename                      string
---@param nodetype                      era.m.explorer.NodeTypeEnum
---@return string
function M.calc_filepath(parent_filepath, nodename, nodetype)
  if parent_filepath == "" then
    if nodetype == "D" then
      return nodename == "" and "/" or (nodename .. "/")
    end
    return nodename
  end

  if nodetype == "D" then
    return parent_filepath .. nodename .. "/"
  end
  return parent_filepath .. nodename
end

---@param node                          era.m.explorer.Node
---@param new_parent                    era.m.explorer.Node
---@return era.m.explorer.Node
function M.clone(node, new_parent)
  ---@type era.m.explorer.Node
  local cloned = {
    filepath = M.calc_filepath(new_parent.filepath, node.nodename, node.nodetype),
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
      local cloned_child = M.clone(child, self) ---@type era.m.explorer.Node
      self.children[i] = cloned_child
      self.chidxmap[cloned_child.nodename] = i
    end
  end

  return self
end

---@param root                          era.m.explorer.Node
---@return era.m.explorer.Node[]
function M.collect_selected(root)
  if not root.has_selected and not root.selected then
    return {}
  end

  local result = {} ---@type era.m.explorer.Node[]

  ---@param node                        era.m.explorer.Node
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

---@param root                          era.m.explorer.Node
---@return era.m.explorer.Node[]
function M.collect_selected_toplevel(root)
  if not root.has_selected and not root.selected then
    return {}
  end

  local result = {} ---@type era.m.explorer.Node[]

  ---@param node                        era.m.explorer.Node
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

---@param root                          era.m.explorer.Node
---@return string[]
function M.collect_selected_filepaths(root)
  if not root.has_selected and not root.selected then
    return {}
  end

  local result = {} ---@type string[]

  ---@param node                        era.m.explorer.Node
  local function traverse(node)
    if node.selected then
      result[#result + 1] = node.filepath
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

---@param parent                        era.m.explorer.Node
---@param nodetype                      era.m.explorer.NodeTypeEnum
---@param nodename                      string
---@return era.m.explorer.Node
function M.new(parent, nodetype, nodename)
  ---@type era.m.explorer.Node
  local node = {
    filepath = M.calc_filepath(parent.filepath, nodename, nodetype),
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

---@param node                          era.m.explorer.Node
---@param new_depth                     integer
---@return nil
function M.refresh_depth(node, new_depth)
  node.depth = new_depth
  for _, child in ipairs(node.children) do
    M.refresh_depth(child, new_depth + 1)
  end
end

---@return era.m.explorer.Node
function M.superroot()
  ---@type era.m.explorer.Node
  local node = {
    filepath = "",
    nodename = "",
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
---@param node                          era.m.explorer.Node
---@return boolean
function M:is_ancestor_of(node)
  if self.filepath == node.filepath then
    return false
  end

  local depth = self.depth ---@type integer
  if node.depth <= depth then
    return false
  end

  local o = node.parent ---@type era.m.explorer.Node|nil
  while o ~= nil and o.depth >= depth do
    if o.filepath == self.filepath then
      return true
    end
    o = o.parent
  end
  return false
end

--- Check if self is an ancestor of the given node, or if they are the same node.
---@param node                          era.m.explorer.Node
---@return boolean
function M:is_ancestor_or_self(node)
  if self.filepath == node.filepath then
    return true
  end

  local depth = self.depth ---@type integer
  if node.depth <= depth then
    return false
  end

  local o = node.parent ---@type era.m.explorer.Node|nil
  while o ~= nil and o.depth >= depth do
    if o.filepath == self.filepath then
      return true
    end
    o = o.parent
  end
  return false
end

--- Check if self is a descendant of the given root.
--- Note: A node is NOT considered a descendant of itself.
---@param root                          era.m.explorer.Node
---@return boolean
function M:is_descendant_of(root)
  if self.filepath == root.filepath then
    return false
  end

  local depth = root.depth ---@type integer
  if self.depth <= depth then
    return false
  end

  local o = self.parent ---@type era.m.explorer.Node|nil
  while o ~= nil and o.depth >= depth do
    if o.filepath == root.filepath then
      return true
    end
    o = o.parent
  end
  return false
end

--- Check if self is a descendant of the given root, or if they are the same node.
---@param root                          era.m.explorer.Node
---@return boolean
function M:is_descendant_or_self(root)
  if self.filepath == root.filepath then
    return true
  end

  local depth = root.depth ---@type integer
  if self.depth <= depth then
    return false
  end

  local o = self.parent ---@type era.m.explorer.Node|nil
  while o ~= nil and o.depth >= depth do
    if o.filepath == root.filepath then
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
  self.has_selected = selected
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
---@param node                          era.m.explorer.Node
---@return nil
function M.sync_ancestors(node)
  local is_selected = node.selected or node.has_selected ---@type boolean
  local p = node.parent ---@type era.m.explorer.Node|nil

  while p ~= nil do
    if is_selected then
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
  local children = self.children ---@type era.m.explorer.Node[]
  local chidxmap = self.chidxmap ---@type table<string, integer|nil>
  for i = start_idx, #children do
    local child = children[i] ---@type era.m.explorer.Node
    chidxmap[child.nodename] = i
  end
end

return M
