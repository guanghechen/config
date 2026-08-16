---@diagnostic disable-next-line: unused-local
local __module_name__ = "era.view.tree.traversal" ---@type string

local EMPTY_CHILDREN = {} ---@type string[]

---@alias era.view.tree.traversal.IVisitor
---| fun(uuid: string, children: string[]): nil `children` is read-only borrowed; the visitor must not mutate tree topology.

local M = {}

---@param tree                          stl.c.IReadonlyTree
---@param root                          string|nil
---@param visit                         era.view.tree.traversal.IVisitor
---@return nil
function M.preorder(tree, root, visit)
  local roots ---@type string[]
  if root == nil or root == tree.root then
    roots = tree:children(tree.root) or EMPTY_CHILDREN
  elseif tree:contains(root) then
    roots = { root }
  else
    return
  end

  local stack_children = { roots } ---@type string[][]
  local stack_indexes = { 1 } ---@type integer[]
  local stack_size = 1 ---@type integer
  while stack_size > 0 do
    local children = stack_children[stack_size] ---@type string[]
    local index = stack_indexes[stack_size] ---@type integer
    if index > #children then
      stack_children[stack_size] = nil
      stack_indexes[stack_size] = nil
      stack_size = stack_size - 1
    else
      stack_indexes[stack_size] = index + 1
      local uuid = children[index] ---@type string
      local descendants = tree:children(uuid) or EMPTY_CHILDREN ---@type string[]
      visit(uuid, descendants)
      if #descendants > 0 then
        stack_size = stack_size + 1
        stack_children[stack_size] = descendants
        stack_indexes[stack_size] = 1
      end
    end
  end
end

return M
