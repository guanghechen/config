local Node = require("dot.module.explorer.node")
local State = require("dot.module.explorer.state")

local __module_name__ = "dot.module.explorer.tree" ---@type string
local math_floor = math.floor

---@class dot.module.explorer.ITreeProps
---@field public name                   string
---@field public protocol               string
---@field public resource_manager       dot.module.explorer.resource.IManager
---@field public initial_root           ?string
---@field public o_flag_foldempty       ?ark.c.Observable
---@field public o_flag_hidden          ?ark.c.Observable

---@class dot.module.explorer.Tree
---@field public name                   string
---@field public fullname               string
---@field public select_mode            dot.module.explorer.SelectModeEnum
---@field public state                  dot.module.explorer.State
---@field protected _disposed           boolean
---@field protected _superroot          dot.module.explorer.Node
---@field protected _root               dot.module.explorer.Node
---@field protected _resource_manager   dot.module.explorer.resource.IManager
local M = {}
M.__index = M

---@param props                         dot.module.explorer.ITreeProps
---@return dot.module.explorer.Tree
function M.new(props)
  local name = props.name ---@type string
  local fullname = string.format("%s@%s", __module_name__, name) ---@type string
  local protocol = props.protocol or "file://" ---@type string
  local resource_manager = props.resource_manager ---@type dot.module.explorer.resource.IManager

  local state = State.new({
    name = name,
    initial_root = props.initial_root,
    o_flag_foldempty = props.o_flag_foldempty,
    o_flag_hidden = props.o_flag_hidden,
  })

  local tick_expanded_odd = state:next_tick_expanded_odd() ---@type integer
  local superroot = Node.superroot(protocol, tick_expanded_odd) ---@type dot.module.explorer.Node

  local self = setmetatable({}, M)
  self.name = name
  self.fullname = fullname
  self.select_mode = "select"
  self.state = state
  self._disposed = false
  self._superroot = superroot
  self._root = superroot
  self._resource_manager = resource_manager

  local initial_root_uri = state.o_root_uri:snapshot() ---@type string
  self:attach(initial_root_uri)

  return self
end

---@return nil
function M:dispose()
  if self._disposed then
    return nil
  end
  self._disposed = true
  self._superroot = nil
  self._root = nil
end

---@return boolean
function M:isdisposed()
  return self._disposed
end

----------------------------------------------------------------------------------------------------
--- Getters
----------------------------------------------------------------------------------------------------

---@return string
function M:get_root_uri()
  self:__health__()
  return self._root.uri
end

---@return dot.module.explorer.Node
function M:get_root_node()
  self:__health__()
  return self._root
end

---@return dot.module.explorer.resource.IManager
function M:get_resource_manager()
  return self._resource_manager
end

---@return dot.module.explorer.Node[]
function M:get_selected_nodes()
  self:__health__()
  return Node.collect_selected(self._superroot)
end

---@return dot.module.explorer.Node[]
function M:get_selected_nodes_toplevel()
  self:__health__()
  return Node.collect_selected_toplevel(self._superroot)
end

---@return string[]
function M:get_selected_uris()
  self:__health__()
  return Node.collect_selected_uris(self._superroot)
end

---@param nodes                         ?dot.module.explorer.Node[]
---@return string|nil
function M:get_common_ancestor_path(nodes)
  self:__health__()

  nodes = nodes or self:get_selected_nodes_toplevel()
  if #nodes == 0 then
    return nil
  end

  local paths = {} ---@type string[]
  for _, node in ipairs(nodes) do
    local filepath = yoz.uri.to_filepath(node.uri) ---@type string|nil
    if filepath ~= nil then
      paths[#paths + 1] = filepath
    end
  end

  local common = dot.path.dirname(paths[1]) ---@type string
  for i = 2, #paths do
    local path = paths[i] ---@type string
    while not yoz.path.is_descendant(common, path) and path ~= common do
      common = dot.path.dirname(common)
      if common == "" or common == "/" then
        return "/"
      end
    end
  end

  return common
end

---@param uri                           string
---@return dot.module.explorer.Node|nil
function M:locate(uri)
  self:__health__()
  return self:__locate__(uri)
end

----------------------------------------------------------------------------------------------------
--- Predicates
----------------------------------------------------------------------------------------------------

---@param rooturi                       string
---@param nodeuri                       string
---@return boolean
function M:is_descendant(rooturi, nodeuri)
  if nodeuri == rooturi then
    return true
  end

  local Nr = #rooturi ---@type integer
  local Nn = #nodeuri ---@type integer
  if Nn <= Nr then
    return false
  end

  if rooturi:sub(Nr, Nr) ~= "/" then
    return false
  end

  return nodeuri:sub(1, Nr) == rooturi
end

---@param uri                           string
---@return boolean
function M:is_existent(uri)
  self:__health__()
  return self:__locate__(uri) ~= nil
end

---@param uri                           string
---@return boolean
function M:is_loaded(uri)
  self:__health__()
  local node = self:__locate__(uri) ---@type dot.module.explorer.Node|nil
  return node ~= nil and node:is_loaded(self.state.tick_loaded)
end

---@param uri                           string
---@return boolean
function M:is_expanded(uri)
  self:__health__()
  local node = self:__locate__(uri) ---@type dot.module.explorer.Node|nil
  local root_uri = self.state.o_root_uri:snapshot() ---@type string
  return node ~= nil and node:is_expanded(root_uri)
end

---@param uri                           string
---@return boolean
function M:is_selected(uri)
  self:__health__()
  local node = self:__locate__(uri) ---@type dot.module.explorer.Node|nil
  local root_uri = self.state.o_root_uri:snapshot() ---@type string
  return node ~= nil and node:is_selected(root_uri)
end

----------------------------------------------------------------------------------------------------
--- Mutations
----------------------------------------------------------------------------------------------------

---@param uri                           string
---@return boolean
function M:attach(uri)
  self:__health__()
  local rm = self._resource_manager ---@type dot.module.explorer.resource.IManager
  local resource = rm:locate(uri) ---@type dot.module.explorer.resource.INode|nil
  if resource == nil then
    ark.reporter.error({
      from = __module_name__,
      subject = self.name,
      message = string.format("Failed to attach node '%s' in %s.", uri, self.name),
    })
    return false
  end

  local node = self:__insert__(uri, resource) ---@type dot.module.explorer.Node
  self:__inherit_root_state__(node)
  local tick_expanded_odd = self.state:next_tick_expanded_odd() ---@type integer
  node:set_expanded(tick_expanded_odd, false)
  self._root = node
  return true
end

---@return nil
function M:clear()
  self:__health__()

  local rootname = self._superroot.nodename ---@type string
  local tick_expanded_odd = self.state:next_tick_expanded_odd() ---@type integer
  local superroot = Node.superroot(rootname, tick_expanded_odd) ---@type dot.module.explorer.Node
  self._superroot = superroot
  self._root = superroot
  self.select_mode = "select"
end

---@param uri                           string
---@return nil
function M:expand_path(uri)
  self:__health__()

  local root = self._root ---@type dot.module.explorer.Node
  local root_uri = root.uri ---@type string

  if not vim.startswith(uri, root_uri) then
    return
  end

  local relative = uri:sub(#root_uri + 1) ---@type string
  local pieces = vim.split(relative, "/", { plain = true }) ---@type string[]

  local node = root ---@type dot.module.explorer.Node
  local current_uri = root_uri ---@type string

  if not node:is_loaded(self.state.tick_loaded) then
    self:__load_children__(node, current_uri)
  end

  local tick_expanded_odd = self.state:next_tick_expanded_odd() ---@type integer
  node:set_expanded(tick_expanded_odd, false)

  for _, piece in ipairs(pieces) do
    if piece == "" then
      goto continue
    end

    local idx = node.chidxmap[piece] ---@type integer|nil
    if idx == nil then
      return
    end

    node = node.children[idx]
    current_uri = current_uri .. piece .. (node.nodetype == "D" and "/" or "")

    if node.nodetype == "D" then
      if not node:is_loaded(self.state.tick_loaded) then
        self:__load_children__(node, current_uri)
      end
      node:set_expanded(tick_expanded_odd, false)
    end

    ::continue::
  end
end

---@param parenturi                     string
---@param resource                      dot.module.explorer.resource.INode
---@return boolean
function M:insert(parenturi, resource)
  self:__health__()

  local rm = self._resource_manager ---@type dot.module.explorer.resource.IManager
  local resource_node = rm:locate(parenturi) ---@type dot.module.explorer.resource.INode|nil
  if resource_node == nil then
    ark.reporter.error({
      from = __module_name__,
      subject = string.format("%s#insert", self.name),
      message = string.format("Cannot insert resource for non-existent URI '%s'.", parenturi),
    })
    return false
  end

  if resource_node.nodetype ~= "D" then
    ark.reporter.error({
      from = __module_name__,
      subject = string.format("%s#insert", self.name),
      message = string.format("Cannot insert resource under non-directory URI '%s'.", parenturi),
    })
    return false
  end

  local parent = self:__insert__(parenturi, resource_node) ---@type dot.module.explorer.Node
  self:__load_children__(parent, parenturi)

  local idx = parent.chidxmap[resource.nodename] ---@type integer|nil
  if idx ~= nil then
    local existing = parent.children[idx] ---@type dot.module.explorer.Node
    if existing.nodetype ~= resource.nodetype then
      ark.reporter.error({
        from = __module_name__,
        subject = string.format("%s#insert", self.name),
        message = string.format(
          "Cannot insert resource '%s' for URI '%s' because a resource with the same name but different type already exists.",
          resource.nodename,
          parenturi
        ),
      })
      return false
    end
    return true
  end

  local children = parent.children ---@type dot.module.explorer.Node[]
  local tick_expanded_even = self.state:next_tick_expanded_even() ---@type integer
  local node = Node.new(parent, resource.nodetype, resource.nodename, tick_expanded_even) ---@type dot.module.explorer.Node
  local insert_idx = self:__find_insertion_index__(rm, children, node) ---@type integer

  table.insert(children, insert_idx, node)
  Node.sync_chidxmap(parent, insert_idx)

  return true
end

---@return nil
function M:mark_all_dirty()
  self:__health__()
  self.state:advance_tick_loaded()
end

---@param node                          dot.module.explorer.Node
---@param resource_manager              dot.module.explorer.resource.IManager|nil
---@param force                         boolean|nil
---@return nil
function M:load_node(node, resource_manager, force)
  self:__health__()
  local _ = resource_manager or self._resource_manager ---@type dot.module.explorer.resource.IManager
  local force_load = not not force ---@type boolean

  if node.nodetype ~= "D" then
    return
  end

  local tick_loaded = self.state.tick_loaded ---@type integer
  if not force_load and node:is_loaded(tick_loaded) then
    return
  end

  local uri = node.uri ---@type string
  self:__load_children__(node, uri)
end

---@param force                         boolean|nil
---@return nil
function M:refresh(force)
  self:__health__()

  local force_refresh = not not force ---@type boolean
  local superroot = self._superroot ---@type dot.module.explorer.Node
  local root = self._root ---@type dot.module.explorer.Node
  local root_uri = root.uri ---@type string
  local tick_loaded = self.state.tick_loaded ---@type integer

  ---@param node                        dot.module.explorer.Node
  ---@param nodeindex                   integer|nil
  ---@param nodeuri                     string
  local function walk(node, nodeindex, nodeuri)
    local load_node = force_refresh or not node:is_loaded(tick_loaded) ---@type boolean

    if node == superroot then
      if load_node then
        self:__load_children__(node, node.uri)
      end
    elseif load_node then
      if nodeindex == nil then
        error(string.format("[refresh] Missing node index for URI '%s'.", nodeuri))
      end
      self:__load__(node, nodeindex, nodeuri, true)
    end

    if not node:is_expanded(root_uri) then
      return
    end

    for index, child in ipairs(node.children) do
      local uri = Node.calc_uri(nodeuri, child.nodename, child.nodetype) ---@type string
      walk(child, index, uri)
    end
  end

  if root == superroot then
    walk(superroot, nil, root_uri)
    return
  end

  local nodeindex = root.parent.chidxmap[root.nodename] ---@type integer
  walk(root, nodeindex, root_uri)
end

---@param uri                           string
---@return boolean
function M:remove(uri)
  self:__health__()

  local node = self:__locate__(uri) ---@type dot.module.explorer.Node|nil
  if node == nil then
    ark.reporter.warn({
      from = __module_name__,
      subject = string.format("%s#remove", self.name),
      message = string.format("Cannot remove non-existent URI '%s'.", uri),
    })
    return false
  end

  local superroot = self._superroot ---@type dot.module.explorer.Node
  if node == superroot then
    ark.reporter.error({
      from = __module_name__,
      subject = string.format("%s#remove", self.name),
      message = "Cannot remove the superroot.",
    })
    return false
  end

  local parent = node.parent ---@type dot.module.explorer.Node|nil
  if parent == nil then
    ark.reporter.error({
      from = __module_name__,
      subject = string.format("%s#remove", self.name),
      message = string.format("Detached node detected while removing '%s'.", uri),
    })
    return false
  end

  local rm = self._resource_manager ---@type dot.module.explorer.resource.IManager
  local removed = false ---@type boolean

  ---@return nil
  local function on_removed()
    if removed then
      return
    end

    local removal_index = parent.chidxmap[node.nodename] ---@type integer|nil
    if removal_index == nil then
      for i, child in ipairs(parent.children) do
        if child == node then
          removal_index = i
          break
        end
      end
    end

    if removal_index == nil then
      ark.reporter.error({
        from = __module_name__,
        subject = string.format("%s#remove", self.name),
        message = string.format("Failed to locate node '%s' during removal callback.", uri),
      })
      return
    end

    if removal_index ~= nil then
      table.remove(parent.children, removal_index)
      Node.sync_chidxmap(parent, removal_index)
    end

    parent.chidxmap[node.nodename] = nil

    if self._root ~= nil then
      if self._root == node or self:__is_descendant__(node, self._root) then
        self._root = parent
      end
    end

    node.parent = nil
    node.children = {}
    node.chidxmap = {}
    node.depth = 0

    removed = true
  end

  local ok, result = pcall(rm.remove, rm, uri, on_removed) ---@type boolean, boolean|nil
  if not ok then
    ark.reporter.error({
      from = __module_name__,
      subject = string.format("%s#remove", self.name),
      message = string.format("Resource manager removal failed for '%s': %s", uri, result),
    })
    return false
  end

  if result == false then
    ark.reporter.error({
      from = __module_name__,
      subject = string.format("%s#remove", self.name),
      message = string.format("Resource manager refused to remove '%s'.", uri),
    })
    return false
  end

  return result ~= false
end

---@param uri                           string
---@param recursive                     boolean
---@param force_expanded                dot.module.explorer.ForceExpandedEnum|nil
---@return nil
function M:toggle_expanded(uri, recursive, force_expanded)
  self:__health__()
  local node = self:__locate__(uri) ---@type dot.module.explorer.Node|nil
  if node == nil then
    return
  end

  local expanded ---@type boolean
  if force_expanded == "expand" then
    expanded = true
  elseif force_expanded == "collapse" then
    expanded = false
  else
    local root_uri = self.state.o_root_uri:snapshot() ---@type string
    expanded = not node:is_expanded(root_uri)
  end

  local tick_expanded ---@type integer
  if expanded then
    tick_expanded = self.state:next_tick_expanded_odd()
  else
    tick_expanded = self.state:next_tick_expanded_even()
  end

  node:set_expanded(tick_expanded, recursive)
end

---@param uri                           string
---@param force_selected                dot.module.explorer.ForceSelectedEnum|nil
---@return nil
function M:toggle_selected(uri, force_selected)
  self:__health__()
  local node = self:__locate__(uri) ---@type dot.module.explorer.Node|nil
  if node == nil then
    return
  end

  local selected ---@type boolean
  if force_selected == "select" then
    selected = true
  elseif force_selected == "unselect" then
    selected = false
  else
    local root_uri = self.state.o_root_uri:snapshot() ---@type string
    selected = not node:is_selected(root_uri)
  end

  local tick_selected ---@type integer
  if selected then
    tick_selected = self.state:next_tick_selected_odd()
  else
    tick_selected = self.state:next_tick_selected_even()
  end

  node:set_selected(tick_selected)
end

---@return nil
function M:clear_selection()
  self:__health__()
  self.state:next_tick_selected_even()
  self.select_mode = "select"
end

----------------------------------------------------------------------------------------------------
--- Cut/Copy/Paste
----------------------------------------------------------------------------------------------------

---@param target_parent_uri             string
---@return boolean
function M:apply_cut_paste(target_parent_uri)
  self:__health__()

  local subject = string.format("%s#apply_cut_paste", self.name) ---@type string
  local target_node = self:__locate__(target_parent_uri) ---@type dot.module.explorer.Node|nil
  if target_node == nil then
    ark.reporter.error({
      from = __module_name__,
      subject = subject,
      message = string.format("Target parent '%s' does not exist.", target_parent_uri),
    })
    return false
  end

  if target_node.nodetype ~= "D" then
    ark.reporter.error({
      from = __module_name__,
      subject = subject,
      message = string.format("Target parent '%s' is not a directory.", target_parent_uri),
    })
    return false
  end

  local target_nodeuri = target_node.uri ---@type string
  local load_uri ---@type string
  if target_node == self._superroot then
    load_uri = target_node.uri
  else
    load_uri = target_nodeuri
  end

  if not target_node:is_loaded(self.state.tick_loaded) then
    self:__load_children__(target_node, load_uri)
  end

  local selected_nodes = Node.collect_selected(self._superroot) ---@type dot.module.explorer.Node[]
  if #selected_nodes == 0 then
    return false
  end

  local reserved = {} ---@type table<string, boolean>
  for name, _ in pairs(target_node.chidxmap) do
    reserved[name] = true
  end

  for _, node in ipairs(selected_nodes) do
    local nodeuri = node.uri ---@type string
    if node == self._superroot then
      ark.reporter.error({
        from = __module_name__,
        subject = subject,
        message = "Cannot move the superroot.",
      })
      return false
    end

    local parent = node.parent ---@type dot.module.explorer.Node|nil
    if parent == nil then
      ark.reporter.error({
        from = __module_name__,
        subject = subject,
        message = string.format("Node '%s' is detached and cannot be moved.", nodeuri),
      })
      return false
    end

    if self:__is_descendant__(node, target_node) then
      ark.reporter.error({
        from = __module_name__,
        subject = subject,
        message = string.format(
          "Target parent '%s' is a descendant of the selected node '%s'.",
          target_parent_uri,
          nodeuri
        ),
      })
      return false
    end

    local existing_idx = target_node.chidxmap[node.nodename] ---@type integer|nil
    if existing_idx ~= nil then
      local existing = target_node.children[existing_idx] ---@type dot.module.explorer.Node
      if existing ~= node then
        ark.reporter.error({
          from = __module_name__,
          subject = subject,
          message = string.format("Target parent '%s' already contains '%s'.", target_parent_uri, node.nodename),
        })
        return false
      end
    elseif reserved[node.nodename] then
      ark.reporter.error({
        from = __module_name__,
        subject = subject,
        message = string.format(
          "Multiple nodes named '%s' cannot be pasted into '%s'.",
          node.nodename,
          target_parent_uri
        ),
      })
      return false
    else
      reserved[node.nodename] = true
    end
  end

  local rm = self._resource_manager ---@type dot.module.explorer.resource.IManager
  local changed = false ---@type boolean

  for _, node in ipairs(selected_nodes) do
    local nodeuri = node.uri ---@type string
    if node.parent ~= target_node then
      local parent = node.parent ---@type dot.module.explorer.Node|nil
      if parent == nil then
        ark.reporter.error({
          from = __module_name__,
          subject = subject,
          message = string.format("Node '%s' is detached and cannot be moved.", nodeuri),
        })
        return false
      end

      local source_uri = nodeuri ---@type string
      local destination_uri = Node.calc_uri(target_nodeuri, node.nodename, node.nodetype) ---@type string

      local ok, result = pcall(rm.move, rm, source_uri, destination_uri) ---@type boolean, boolean|nil
      if not ok then
        ark.reporter.error({
          from = __module_name__,
          subject = subject,
          message = string.format("Resource manager move failed for '%s'.", source_uri),
          details = { target = destination_uri, error = result },
        })
        return false
      end

      if result == false or result == nil then
        ark.reporter.error({
          from = __module_name__,
          subject = subject,
          message = string.format("Resource manager refused to move '%s'.", source_uri),
          details = { target = destination_uri },
        })
        return false
      end

      local removal_index = parent.chidxmap[node.nodename] ---@type integer|nil
      if removal_index == nil then
        for index, child in ipairs(parent.children) do
          if child == node then
            removal_index = index
            break
          end
        end
      end

      if removal_index == nil then
        ark.reporter.error({
          from = __module_name__,
          subject = subject,
          message = string.format("Cannot locate node '%s' in its parent list.", source_uri),
          details = { target = destination_uri },
        })
        return false
      end

      table.remove(parent.children, removal_index)
      parent.chidxmap[node.nodename] = nil
      Node.sync_chidxmap(parent, removal_index)

      node.parent = target_node
      node.rs.tick_expanded = target_node.rs.tick_expanded
      node.rs.tick_selected = target_node.rs.tick_selected
      Node.refresh_depth(node, target_node.depth + 1)
      local insert_idx = self:__find_insertion_index__(rm, target_node.children, node) ---@type integer
      table.insert(target_node.children, insert_idx, node)
      Node.sync_chidxmap(target_node, insert_idx)

      changed = true
    end
  end

  return changed
end

---@param target_parent_uri             string
---@return boolean
function M:apply_copy_paste(target_parent_uri)
  self:__health__()

  local subject = string.format("%s#apply_copy_paste", self.name) ---@type string
  local target_node = self:__locate__(target_parent_uri) ---@type dot.module.explorer.Node|nil
  if target_node == nil then
    ark.reporter.error({
      from = __module_name__,
      subject = subject,
      message = string.format("Target parent '%s' does not exist.", target_parent_uri),
    })
    return false
  end

  if target_node.nodetype ~= "D" then
    ark.reporter.error({
      from = __module_name__,
      subject = subject,
      message = string.format("Target parent '%s' is not a directory.", target_parent_uri),
    })
    return false
  end

  local target_nodeuri = target_node.uri ---@type string
  local load_uri ---@type string
  if target_node == self._superroot then
    load_uri = target_node.uri
  else
    load_uri = target_nodeuri
  end

  if not target_node:is_loaded(self.state.tick_loaded) then
    self:__load_children__(target_node, load_uri)
  end

  local selected_nodes = Node.collect_selected(self._superroot) ---@type dot.module.explorer.Node[]
  if #selected_nodes == 0 then
    return false
  end

  local reserved = {} ---@type table<string, boolean>
  for name, _ in pairs(target_node.chidxmap) do
    reserved[name] = true
  end

  for _, node in ipairs(selected_nodes) do
    local nodeuri = node.uri ---@type string
    if node == self._superroot then
      ark.reporter.error({
        from = __module_name__,
        subject = subject,
        message = "Cannot copy the superroot.",
      })
      return false
    end

    if node.parent == nil then
      ark.reporter.error({
        from = __module_name__,
        subject = subject,
        message = string.format("Node '%s' is detached and cannot be copied.", nodeuri),
      })
      return false
    end

    if self:__is_descendant__(node, target_node) then
      ark.reporter.error({
        from = __module_name__,
        subject = subject,
        message = string.format(
          "Target parent '%s' is a descendant of the selected node '%s'.",
          target_parent_uri,
          nodeuri
        ),
      })
      return false
    end

    local existing_idx = target_node.chidxmap[node.nodename] ---@type integer|nil
    if existing_idx ~= nil then
      ark.reporter.error({
        from = __module_name__,
        subject = subject,
        message = string.format("Target parent '%s' already contains '%s'.", target_parent_uri, node.nodename),
      })
      return false
    end

    if reserved[node.nodename] then
      ark.reporter.error({
        from = __module_name__,
        subject = subject,
        message = string.format(
          "Multiple nodes named '%s' cannot be pasted into '%s'.",
          node.nodename,
          target_parent_uri
        ),
      })
      return false
    end

    reserved[node.nodename] = true
  end

  local rm = self._resource_manager ---@type dot.module.explorer.resource.IManager
  local changed = false ---@type boolean
  local tick_expanded_even = self.state:next_tick_expanded_even() ---@type integer

  for _, node in ipairs(selected_nodes) do
    local source_uri = node.uri ---@type string
    local destination_uri = Node.calc_uri(target_nodeuri, node.nodename, node.nodetype) ---@type string

    local ok, result = pcall(rm.copy, rm, source_uri, destination_uri) ---@type boolean, boolean|nil
    if not ok then
      ark.reporter.error({
        from = __module_name__,
        subject = subject,
        message = string.format("Resource manager copy failed for '%s'.", source_uri),
        details = { target = destination_uri, error = result },
      })
      return false
    end

    if result == false or result == nil then
      ark.reporter.error({
        from = __module_name__,
        subject = subject,
        message = string.format("Resource manager refused to copy '%s'.", source_uri),
        details = { target = destination_uri },
      })
      return false
    end

    local clone = Node.clone(node, target_node, tick_expanded_even) ---@type dot.module.explorer.Node
    Node.refresh_depth(clone, target_node.depth + 1)
    local insert_idx = self:__find_insertion_index__(rm, target_node.children, clone) ---@type integer
    table.insert(target_node.children, insert_idx, clone)
    Node.sync_chidxmap(target_node, insert_idx)
    changed = true
  end

  return changed
end

----------------------------------------------------------------------------------------------------
--- Protected
----------------------------------------------------------------------------------------------------

---@protected
---@param uri                           string
---@return dot.module.explorer.NodeTypeEnum
function M:__detect_nodetype__(uri)
  local nodetype = uri:sub(-1) == "/" and "D" or "F" ---@type dot.module.explorer.NodeTypeEnum
  return nodetype
end

---@protected
---@param resource_manager              dot.module.explorer.resource.IManager
---@param children                      dot.module.explorer.Node[]
---@param candidate                     dot.module.explorer.Node
---@return integer
function M:__find_insertion_index__(resource_manager, children, candidate)
  local lo = 1 ---@type integer
  local hi = #children ---@type integer
  while lo <= hi do
    local mid = math_floor((lo + hi) / 2) ---@type integer
    local delta = resource_manager.compare(candidate, children[mid]) ---@type integer
    if delta >= 0 then
      lo = mid + 1
    else
      hi = mid - 1
    end
  end
  return lo
end

---@protected
---@param root                          dot.module.explorer.Node
---@return nil
function M:__inherit_root_state__(root)
  local max_tick_expanded = root.rs.tick_expanded ---@type integer
  local max_tick_selected = root.rs.tick_selected ---@type integer

  local o = root.parent ---@type dot.module.explorer.Node|nil
  while o ~= nil do
    max_tick_expanded = math.max(max_tick_expanded, o.rs.tick_expanded)
    max_tick_selected = math.max(max_tick_selected, o.rs.tick_selected)
    o = o.parent
  end

  root.rs.tick_expanded = max_tick_expanded
  root.rs.tick_selected = max_tick_selected
end

---@protected
---@return nil
function M:__health__()
  if self._disposed then
    local message = string.format("%s has been disposed.", self.name) ---@type string
    error(message)
  end
end

---@param uri                           string
---@param resource                      dot.module.explorer.resource.INode|nil
---@param ensure_resource               boolean|nil
---@return dot.module.explorer.Node
---@return boolean
function M:__insert__(uri, resource, ensure_resource)
  local superroot = self._superroot ---@type dot.module.explorer.Node
  local superroot_uri = superroot.uri ---@type string
  if superroot_uri == uri then
    return superroot, false
  end

  local rm = self._resource_manager ---@type dot.module.explorer.resource.IManager
  local ensure_created = ensure_resource == true ---@type boolean
  if resource == nil then
    if ensure_created then
      if rm:insert_if_missing(uri) == false then
        local message = string.format("Failed to create node URI: '%s'.", uri) ---@type string
        error(message)
      end
      resource = rm:locate(uri) ---@type dot.module.explorer.resource.INode|nil
      if resource == nil then
        local message = string.format("Failed to locate node URI after creation: '%s'.", uri) ---@type string
        error(message)
      end
    else
      resource = rm:locate(uri) ---@type dot.module.explorer.resource.INode|nil
      if resource == nil then
        local message = string.format("Cannot materialize non-existent node URI: '%s'.", uri) ---@type string
        error(message)
      end
    end
  end

  local Ns = #superroot_uri ---@type integer
  local Nn = #uri ---@type integer
  if Nn <= Ns then
    local message = string.format("Invalid node URI: '%s'. Must be descendant of the superroot", uri) ---@type string
    error(message)
  end

  local nodetype = resource ~= nil and resource.nodetype or self:__detect_nodetype__(uri) ---@type dot.module.explorer.NodeTypeEnum
  local raw_pieces = vim.split(uri:sub(Ns + 1), "/", { plain = true }) ---@type string[]
  local pieces = {} ---@type string[]
  for _, piece in ipairs(raw_pieces) do
    if piece ~= "" then
      pieces[#pieces + 1] = piece
    end
  end

  local o = superroot ---@type dot.module.explorer.Node
  local n = #pieces ---@type integer

  if n == 0 then
    return superroot, false
  end

  local new_created = false ---@type boolean
  local tick_expanded_even = self.state:next_tick_expanded_even() ---@type integer

  for i = 1, n, 1 do
    local piece = pieces[i] ---@type string

    local idx = o.chidxmap[piece] ---@type integer|nil
    if idx == nil then
      local child_nodetype = i == n and nodetype or "D" ---@type dot.module.explorer.NodeTypeEnum
      local child = Node.new(o, child_nodetype, piece, tick_expanded_even) ---@type dot.module.explorer.Node
      local insert_idx = self:__find_insertion_index__(rm, o.children, child) ---@type integer

      table.insert(o.children, insert_idx, child)
      Node.sync_chidxmap(o, insert_idx)

      o = child
      new_created = true
    else
      o = o.children[idx] ---@type dot.module.explorer.Node
    end
  end
  o.uri = Node.calc_uri(o.parent.uri, o.nodename, o.nodetype)
  return o, new_created
end

---@protected
---@param root                          dot.module.explorer.Node
---@param node                          dot.module.explorer.Node
---@return boolean
function M:__is_descendant__(root, node)
  if root == node then
    return true
  end

  if node.depth <= root.depth then
    return false
  end

  local o = node.parent ---@type dot.module.explorer.Node|nil
  while o ~= nil do
    if o == root then
      return true
    end
    o = o.parent
  end
  return false
end

---@param node                          dot.module.explorer.Node
---@param nodeindex                     integer
---@param uri                           string
---@param force                         boolean
---@return dot.module.explorer.Node
function M:__load__(node, nodeindex, uri, force)
  local superroot = self._superroot ---@type dot.module.explorer.Node
  local tick_loaded = self.state.tick_loaded ---@type integer

  if node == superroot then
    if force or not node:is_loaded(tick_loaded) then
      self:__load_children__(node, uri)
    end
    return node
  end

  local rm = self._resource_manager ---@type dot.module.explorer.resource.IManager
  local resource_node = rm:locate(uri) ---@type dot.module.explorer.resource.INode|nil
  if resource_node == nil then
    local message = string.format("[__load__] Failed to load non-existent node URI: '%s'.", uri) ---@type string
    error(message)
  end

  if node.nodetype ~= resource_node.nodetype then
    local parent = node.parent ---@type dot.module.explorer.Node|nil
    if parent == nil then
      error(string.format("[__load__] Parent is nil for node URI: '%s'.", uri))
    end
    local _ = self.state:next_tick_expanded_even() ---@type integer

    ---@type dot.module.explorer.node.IRootState
    local rs = {
      tick_expanded = parent.rs.tick_expanded,
      tick_selected = parent.rs.tick_selected,
    }

    ---@type dot.module.explorer.node.INodeState
    local ns = {
      tick_expanded = node.ns.tick_expanded,
      tick_loaded = resource_node.nodetype == "F" and tick_loaded or 0,
    }

    ---@type dot.module.explorer.Node
    local new_node = setmetatable({
      uri = uri,
      nodetype = resource_node.nodetype,
      nodename = resource_node.nodename,
      parent = parent,
      children = {},
      chidxmap = {},
      depth = parent.depth + 1,
      rs = rs,
      ns = ns,
    }, Node)

    node.parent.children[nodeindex] = new_node

    if resource_node.nodetype == "D" then
      self:__load_children__(new_node, uri)
    end
    return new_node
  end

  node.uri = uri

  if node.nodetype == "F" then
    node:mark_loaded(tick_loaded)
    return node
  end

  if not force and node:is_loaded(tick_loaded) then
    return node
  end

  self:__load_children__(node, uri)
  return node
end

---@param node                          dot.module.explorer.Node
---@param uri                           string
---@return nil
function M:__load_children__(node, uri)
  local rm = self._resource_manager ---@type dot.module.explorer.resource.IManager
  local items = rm:load(uri) ---@type dot.module.explorer.resource.INode[]

  local base_uri = node.uri ---@type string
  for _, item in ipairs(items) do
    if item.uri == nil then
      item.uri = Node.calc_uri(base_uri, item.nodename, item.nodetype)
    end
  end

  local tick_loaded = self.state.tick_loaded ---@type integer
  local tick_expanded_even = self.state:next_tick_expanded_even() ---@type integer
  local children = node.children ---@type dot.module.explorer.Node[]
  local chidxmap = node.chidxmap ---@type table<string, integer|nil>
  local child_count = #children ---@type integer
  local item_count = #items ---@type integer

  local unchanged = child_count == item_count ---@type boolean
  if unchanged and child_count > 0 then
    for index = 1, child_count, 1 do
      local child = children[index] ---@type dot.module.explorer.Node|nil
      local item = items[index] ---@type dot.module.explorer.resource.INode
      if child == nil or child.nodename ~= item.nodename or child.nodetype ~= item.nodetype then
        unchanged = false
        break
      end
    end
  end

  if unchanged then
    for index = 1, child_count, 1 do
      local child = children[index] ---@type dot.module.explorer.Node
      child.uri = Node.calc_uri(node.uri, child.nodename, child.nodetype)
      chidxmap[child.nodename] = index
      if child.nodetype == "F" then
        child:mark_loaded(tick_loaded)
      end
    end
    node:mark_loaded(tick_loaded)
    return
  end

  local new_children = {} ---@type dot.module.explorer.Node[]
  local new_chidxmap = {} ---@type table<string, integer|nil>
  for i, item in ipairs(items) do
    local old_index = chidxmap[item.nodename] ---@type integer|nil
    local old_child = old_index ~= nil and children[old_index] or nil ---@type dot.module.explorer.Node|nil
    if old_child == nil or old_child.nodetype ~= item.nodetype then
      local child = Node.new(node, item.nodetype, item.nodename, tick_expanded_even) ---@type dot.module.explorer.Node
      child.uri = Node.calc_uri(node.uri, child.nodename, child.nodetype)
      if item.nodetype == "F" then
        child:mark_loaded(tick_loaded)
      end
      new_children[i] = child
      new_chidxmap[item.nodename] = i
    else
      old_child.parent = node
      old_child.uri = Node.calc_uri(node.uri, old_child.nodename, old_child.nodetype)
      if old_child.nodetype == "F" then
        old_child:mark_loaded(tick_loaded)
      end
      new_children[i] = old_child
      new_chidxmap[item.nodename] = i
    end
  end
  node.children = new_children
  node.chidxmap = new_chidxmap
  node:mark_loaded(tick_loaded)
end

---@param uri                           string
---@return dot.module.explorer.Node|nil
function M:__locate__(uri)
  local superroot = self._superroot ---@type dot.module.explorer.Node
  local superroot_uri = superroot.uri ---@type string
  if superroot_uri == uri then
    return superroot
  end

  local Ns = #superroot_uri ---@type integer
  local Nn = #uri ---@type integer
  if Nn <= Ns then
    return nil
  end

  local o = superroot ---@type dot.module.explorer.Node
  local raw_pieces = vim.split(uri:sub(Ns + 1), "/", { plain = true }) ---@type string[]
  local pieces = {} ---@type string[]
  for _, piece in ipairs(raw_pieces) do
    if piece ~= "" then
      pieces[#pieces + 1] = piece
    end
  end

  local n = #pieces ---@type integer
  if n == 0 then
    return superroot
  end

  for i = 1, n, 1 do
    local piece = pieces[i] ---@type string
    local idx = o.chidxmap[piece] ---@type integer|nil
    if idx == nil then
      return nil
    end
    o = o.children[idx] ---@type dot.module.explorer.Node
  end
  return o
end

return M
