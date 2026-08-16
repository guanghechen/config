---@diagnostic disable-next-line: unused-local
local __module_name__ = "stl.view.treeview" ---@type string

---@class stl.view.treeview.ILayoutProps
---@field public roots any[]
---@field public id ?fun(node: any): string
---@field public children fun(node: any): any[]
---@field public collapsed table<string, true>|nil
---@field public can_fold ?fun(parent: any, child: any): boolean

---@class stl.view.TreeLayout
---@field private _len integer
---@field private _last_root_lnum integer
---@field private _ids string[]
---@field private _depths integer[]
---@field private _parent_lnums integer[]
---@field private _last_child_lnums integer[]
---@field private _last_descendant_lnums integer[]
---@field private _id_to_lnum table<string, integer>
---@field private _folded_ids_by_lnum table<integer, string[]>
local TreeLayout = {}
TreeLayout.__index = TreeLayout

---@param state { ids: string[], depths: integer[], parent_lnums: integer[], last_root_lnum: integer, last_child_lnums: integer[], last_descendant_lnums: integer[], id_to_lnum: table<string, integer>, folded_ids_by_lnum: table<integer, string[]> }
---@return stl.view.TreeLayout
function TreeLayout.__new(state)
  return setmetatable({
    _len = #state.ids,
    _last_root_lnum = state.last_root_lnum,
    _ids = state.ids,
    _depths = state.depths,
    _parent_lnums = state.parent_lnums,
    _last_child_lnums = state.last_child_lnums,
    _last_descendant_lnums = state.last_descendant_lnums,
    _id_to_lnum = state.id_to_lnum,
    _folded_ids_by_lnum = state.folded_ids_by_lnum,
  }, TreeLayout)
end

---@return integer
function TreeLayout:len()
  return self._len
end

---@return integer|nil
function TreeLayout:last_root_lnum()
  return self._last_root_lnum > 0 and self._last_root_lnum or nil
end

---@param lnum integer
---@return string|nil
function TreeLayout:id(lnum)
  return self._ids[lnum]
end

---@param id string
---@return integer|nil
function TreeLayout:lnum(id)
  return self._id_to_lnum[id]
end

---@param lnum integer
---@return integer|nil
function TreeLayout:depth(lnum)
  return self._depths[lnum]
end

---@param lnum integer
---@return string[]|nil Read-only IDs merged into this row, including the representative ID.
function TreeLayout:folded_ids(lnum)
  return self._folded_ids_by_lnum[lnum]
end

---@param lnum integer
---@return integer|nil
function TreeLayout:parent_lnum(lnum)
  local parent_lnum = self._parent_lnums[lnum]
  return parent_lnum ~= nil and parent_lnum > 0 and parent_lnum or nil
end

---@param lnum integer
---@return integer|nil
function TreeLayout:first_child_lnum(lnum)
  if self._ids[lnum] == nil then
    return nil
  end
  local candidate = lnum + 1 ---@type integer
  return self._parent_lnums[candidate] == lnum and candidate or nil
end

---@param lnum integer
---@return integer|nil
function TreeLayout:last_child_lnum(lnum)
  local last_child_lnum = self._last_child_lnums[lnum]
  return last_child_lnum ~= nil and last_child_lnum > 0 and last_child_lnum or nil
end

---@param lnum integer
---@return integer|nil
function TreeLayout:last_descendant_lnum(lnum)
  return self._last_descendant_lnums[lnum]
end

---@param lnum integer
---@return integer|nil
function TreeLayout:next_sibling_lnum(lnum)
  local last_descendant_lnum = self._last_descendant_lnums[lnum]
  if last_descendant_lnum == nil then
    return nil
  end

  local candidate = last_descendant_lnum + 1 ---@type integer
  return candidate <= self._len and self._parent_lnums[candidate] == self._parent_lnums[lnum] and candidate or nil
end

---@param lnum integer
---@return boolean|nil
function TreeLayout:is_last(lnum)
  if self._ids[lnum] == nil then
    return nil
  end
  return self:next_sibling_lnum(lnum) == nil
end

---@class stl.view.treeview
---@field public layout fun(props: stl.view.treeview.ILayoutProps): stl.view.TreeLayout
local M = {}

---@param message string
---@return never
local function fail(message)
  error(string.format("[%s] %s", __module_name__, message), 3)
end

---@param props stl.view.treeview.ILayoutProps
---@return stl.view.TreeLayout
function M.layout(props)
  if type(props) ~= "table" then
    fail("props must be a table")
  end

  local roots = props.roots ---@type any[]
  if type(roots) ~= "table" then
    fail("roots must be a table")
  end

  local resolve_id = props.id
  if resolve_id ~= nil and type(resolve_id) ~= "function" then
    fail("id must be a function")
  end

  local children = props.children
  if type(children) ~= "function" then
    fail("children must be a function")
  end

  local collapsed = props.collapsed
  if collapsed ~= nil and type(collapsed) ~= "table" then
    fail("collapsed must be a table")
  end

  local can_fold = props.can_fold
  if can_fold ~= nil and type(can_fold) ~= "function" then
    fail("can_fold must be a function")
  end

  local ids = {} ---@type string[]
  local depths = {} ---@type integer[]
  local parent_lnums = {} ---@type integer[]
  local last_child_lnums = {} ---@type integer[]
  local last_descendant_lnums = {} ---@type integer[]
  local id_to_lnum = {} ---@type table<string, integer>
  local folded_ids_by_lnum = {} ---@type table<integer, string[]>
  local last_root_lnum = 0 ---@type integer

  -- Each stack slot is one active sibling list. Slot 1 is the virtual forest root.
  local stack_children = { roots } ---@type any[][]
  local stack_indexes = { 1 } ---@type integer[]
  local stack_owner_lnums = { 0 } ---@type integer[]
  local stack_size = 1 ---@type integer

  while stack_size > 0 do
    local child_nodes = stack_children[stack_size] ---@type any[]
    local child_index = stack_indexes[stack_size] ---@type integer

    if child_index > #child_nodes then
      local owner_lnum = stack_owner_lnums[stack_size] ---@type integer
      if owner_lnum > 0 then
        last_descendant_lnums[owner_lnum] = #ids
      end

      stack_children[stack_size] = nil
      stack_indexes[stack_size] = nil
      stack_owner_lnums[stack_size] = nil
      stack_size = stack_size - 1
    else
      stack_indexes[stack_size] = child_index + 1

      local node = child_nodes[child_index]
      local id = resolve_id ~= nil and resolve_id(node) or node ---@type any
      if type(id) ~= "string" then
        fail(string.format("node id must be a string, got %s", type(id)))
      end

      local lnum = #ids + 1 ---@type integer
      local parent_lnum = stack_owner_lnums[stack_size] ---@type integer

      depths[lnum] = stack_size - 1
      parent_lnums[lnum] = parent_lnum
      last_child_lnums[lnum] = 0
      if parent_lnum > 0 then
        last_child_lnums[parent_lnum] = lnum
      else
        last_root_lnum = lnum
      end

      local folded_ids = nil ---@type string[]|nil
      while true do
        if id_to_lnum[id] ~= nil then
          fail(string.format("node '%s' appears more than once", id))
        end

        ids[lnum] = id
        id_to_lnum[id] = lnum
        if folded_ids ~= nil then
          folded_ids[#folded_ids + 1] = id
        end

        if collapsed ~= nil and collapsed[id] then
          last_descendant_lnums[lnum] = lnum
          break
        end

        local next_children = children(node) ---@type any[]
        if type(next_children) ~= "table" then
          fail(string.format("children result for node '%s' must be a table", id))
        end

        local child_count = #next_children ---@type integer
        if child_count == 0 then
          last_descendant_lnums[lnum] = lnum
          break
        end

        local folded_child_id = nil ---@type string|nil
        local folded_child = nil
        if child_count == 1 and can_fold ~= nil then
          local child = next_children[1]
          local should_fold = can_fold(node, child) ---@type boolean
          if type(should_fold) ~= "boolean" then
            fail(string.format("can_fold result for node '%s' must be a boolean", id))
          end
          if should_fold then
            local child_id = resolve_id ~= nil and resolve_id(child) or child ---@type any
            if type(child_id) ~= "string" then
              fail(string.format("node id must be a string, got %s", type(child_id)))
            end
            if id_to_lnum[child_id] ~= nil then
              fail(string.format("node '%s' appears more than once", child_id))
            end
            folded_child_id = child_id
            folded_child = child
          end
        end

        if folded_child_id ~= nil then
          if folded_ids == nil then
            folded_ids = { id }
            folded_ids_by_lnum[lnum] = folded_ids
          end
          id = folded_child_id
          node = folded_child
        else
          stack_size = stack_size + 1
          stack_children[stack_size] = next_children
          stack_indexes[stack_size] = 1
          stack_owner_lnums[stack_size] = lnum
          break
        end
      end
    end
  end

  return TreeLayout.__new({
    ids = ids,
    depths = depths,
    parent_lnums = parent_lnums,
    last_root_lnum = last_root_lnum,
    last_child_lnums = last_child_lnums,
    last_descendant_lnums = last_descendant_lnums,
    id_to_lnum = id_to_lnum,
    folded_ids_by_lnum = folded_ids_by_lnum,
  })
end

return M
