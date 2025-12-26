---@class dot.module.explorer.Node : dot.module.explorer.resource.INode
---@field public uri                    string
---@field public nodename               string
---@field public nodetype               dot.module.explorer.NodeTypeEnum
---@field public parent                 dot.module.explorer.Node|nil
---@field public children               dot.module.explorer.Node[]
---@field public chidxmap               table<string, integer|nil>
---@field public depth                  integer
---@field public expanded               boolean
---@field public loaded                 boolean
---@field public selected               boolean
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
    expanded = false,
    loaded = node.nodetype == "F",
    selected = false,
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
  local result = {} ---@type dot.module.explorer.Node[]

  ---@param node                        dot.module.explorer.Node
  local function traverse(node)
    if node.selected then
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
---@return dot.module.explorer.Node[]
function M.collect_selected_toplevel(root)
  local result = {} ---@type dot.module.explorer.Node[]

  ---@param node                        dot.module.explorer.Node
  local function traverse(node)
    if node.selected then
      result[#result + 1] = node
      return
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
    if node.selected then
      result[#result + 1] = node.uri
    end
    for _, child in ipairs(node.children) do
      traverse(child)
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
    expanded = false,
    loaded = nodetype == "F",
    selected = false,
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
    expanded = true,
    loaded = false,
    selected = false,
  }

  local self = setmetatable(node, M)
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
  for _, child in ipairs(self.children) do
    child:set_selected_recursive(selected)
  end
end

return M
