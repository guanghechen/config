---@diagnostic disable-next-line: unused-local
local __module_name__ = "era.m.explorer.tree" ---@type string

---@class era.m.explorer.ITreeProps
---@field public name                   string
---@field public resource_manager       era.m.explorer.resource.IManager
---@field public initial_root           ?string
---@field public o_flag_foldempty       stl.c.Observable
---@field public o_flag_hidden          stl.c.Observable

---@class era.m.explorer.Tree
---@field public fullname               string
---@field public name                   string
---@field public o_cursor_filepath           stl.c.Observable
---@field public o_flag_foldempty       stl.c.Observable
---@field public o_flag_hidden          stl.c.Observable
---@field public o_root_filepath             stl.c.Observable
---@field public prev_root_filepath          string|nil
---@field public select_mode            era.m.explorer.SelectModeEnum
---@field public ticks                  era.m.explorer.ITreeTicks
---@field protected _disposed           boolean
---@field protected _resource_manager   era.m.explorer.resource.IManager
---@field protected _root               era.m.explorer.Node
---@field protected _superroot          era.m.explorer.Node
local M = {}
M.__index = M

---@param filepath                      string
---@param keep_trailing_slash           boolean|nil
---@return string
local function normalize_filepath(filepath, keep_trailing_slash)
  return dot.path.normalize(filepath, keep_trailing_slash ~= false, "/")
end

---@param filepath                      string
---@return string
local function normalize_dirpath(filepath)
  local normalized = normalize_filepath(filepath, true) ---@type string
  if normalized:sub(-1) ~= "/" then
    normalized = normalized .. "/"
  end
  return normalized
end

---@param path                          string
---@return string[]
local function split_path_pieces(path)
  local raw_pieces = vim.split(path, "/", { plain = true }) ---@type string[]
  local pieces = {} ---@type string[]
  for i, piece in ipairs(raw_pieces) do
    if piece ~= "" then
      pieces[#pieces + 1] = piece
    elseif i == 1 and path:sub(1, 1) == "/" then
      -- Preserve Unix root marker: "/a/b" -> {"", "a", "b"}
      pieces[#pieces + 1] = ""
    end
  end
  return pieces
end

---@param props                         era.m.explorer.ITreeProps
---@return era.m.explorer.Tree
function M.new(props)
  local name = props.name ---@type string
  local fullname = string.format("%s@%s", __module_name__, name) ---@type string
  local resource_manager = props.resource_manager ---@type era.m.explorer.resource.IManager
  local initial_root = props.initial_root ---@type string|nil
  local default_root = normalize_dirpath(initial_root or dot.path.cwd()) ---@type string

  local superroot = era.m.explorer.Node.superroot() ---@type era.m.explorer.Node

  local self = setmetatable({}, M)
  self.fullname = fullname
  self.name = name
  self.o_cursor_filepath = stl.c.Observable.from_value(default_root)
  self.o_flag_foldempty = props.o_flag_foldempty
  self.o_flag_hidden = props.o_flag_hidden
  self.o_root_filepath = stl.c.Observable.from_value(default_root)
  self.prev_root_filepath = nil
  self.select_mode = "select"
  self.ticks = { structure = 0 }
  self._disposed = false
  self._resource_manager = resource_manager
  self._root = superroot
  self._superroot = superroot

  self:attach(default_root)

  return self
end

---@param target_parent_filepath             string
---@return boolean
function M:apply_copy_paste(target_parent_filepath)
  self:__health__()

  local subject = string.format("%s#apply_copy_paste", self.name) ---@type string
  local target_node = self:__locate__(target_parent_filepath) ---@type era.m.explorer.Node|nil
  if target_node == nil then
    stl.reporter.error({
      from = __module_name__,
      subject = subject,
      message = string.format("Target parent '%s' does not exist.", target_parent_filepath),
    })
    return false
  end

  if target_node.nodetype ~= "D" then
    stl.reporter.error({
      from = __module_name__,
      subject = subject,
      message = string.format("Target parent '%s' is not a directory.", target_parent_filepath),
    })
    return false
  end

  local target_node_filepath = target_node.filepath ---@type string

  if not target_node.loaded then
    self:__load_children__(target_node, target_node_filepath)
  end

  local selected_nodes = era.m.explorer.Node.collect_selected(self._root) ---@type era.m.explorer.Node[]
  if #selected_nodes == 0 then
    return false
  end

  local reserved = {} ---@type table<string, boolean>
  for name, _ in pairs(target_node.chidxmap) do
    reserved[name] = true
  end

  for _, node in ipairs(selected_nodes) do
    local node_filepath = node.filepath ---@type string
    if node == self._root then
      stl.reporter.error({
        from = __module_name__,
        subject = subject,
        message = "Cannot copy the root.",
      })
      return false
    end

    if node.parent == nil then
      stl.reporter.error({
        from = __module_name__,
        subject = subject,
        message = string.format("Node '%s' is detached and cannot be copied.", node_filepath),
      })
      return false
    end

    if target_node:is_descendant_or_self(node) then
      stl.reporter.error({
        from = __module_name__,
        subject = subject,
        message = string.format(
          "Target parent '%s' is a descendant of the selected node '%s'.",
          target_parent_filepath,
          node_filepath
        ),
      })
      return false
    end

    local existing_idx = target_node.chidxmap[node.nodename] ---@type integer|nil
    if existing_idx ~= nil then
      stl.reporter.error({
        from = __module_name__,
        subject = subject,
        message = string.format("Target parent '%s' already contains '%s'.", target_parent_filepath, node.nodename),
      })
      return false
    end

    if reserved[node.nodename] then
      stl.reporter.error({
        from = __module_name__,
        subject = subject,
        message = string.format(
          "Multiple nodes named '%s' cannot be pasted into '%s'.",
          node.nodename,
          target_parent_filepath
        ),
      })
      return false
    end

    reserved[node.nodename] = true
  end

  local rm = self._resource_manager ---@type era.m.explorer.resource.IManager
  local changed = false ---@type boolean

  for _, node in ipairs(selected_nodes) do
    local source_filepath = node.filepath ---@type string
    local destination_filepath = era.m.explorer.Node.calc_filepath(target_node_filepath, node.nodename, node.nodetype) ---@type string

    local ok, result = pcall(rm.copy, rm, source_filepath, destination_filepath) ---@type boolean, boolean|nil
    if not ok then
      stl.reporter.error({
        from = __module_name__,
        subject = subject,
        message = string.format("Resource manager copy failed for '%s'.", source_filepath),
        details = { target = destination_filepath, error = result },
      })
      return false
    end

    if result == false or result == nil then
      stl.reporter.error({
        from = __module_name__,
        subject = subject,
        message = string.format("Resource manager refused to copy '%s'.", source_filepath),
        details = { target = destination_filepath },
      })
      return false
    end

    local clone = era.m.explorer.Node.clone(node, target_node) ---@type era.m.explorer.Node
    era.m.explorer.Node.refresh_depth(clone, target_node.depth + 1)
    local insert_idx = self:__find_insertion_index__(rm, target_node.children, clone) ---@type integer
    table.insert(target_node.children, insert_idx, clone)
    target_node:sync_chidxmap(insert_idx)
    changed = true
  end

  if changed then
    self.ticks.structure = self.ticks.structure + 1
  end
  return changed
end

---@param target_parent_filepath             string
---@return boolean
function M:apply_cut_paste(target_parent_filepath)
  self:__health__()

  local subject = string.format("%s#apply_cut_paste", self.name) ---@type string
  local target_node = self:__locate__(target_parent_filepath) ---@type era.m.explorer.Node|nil
  if target_node == nil then
    stl.reporter.error({
      from = __module_name__,
      subject = subject,
      message = string.format("Target parent '%s' does not exist.", target_parent_filepath),
    })
    return false
  end

  if target_node.nodetype ~= "D" then
    stl.reporter.error({
      from = __module_name__,
      subject = subject,
      message = string.format("Target parent '%s' is not a directory.", target_parent_filepath),
    })
    return false
  end

  local target_node_filepath = target_node.filepath ---@type string

  if not target_node.loaded then
    self:__load_children__(target_node, target_node_filepath)
  end

  local selected_nodes = era.m.explorer.Node.collect_selected(self._root) ---@type era.m.explorer.Node[]
  if #selected_nodes == 0 then
    return false
  end

  local reserved = {} ---@type table<string, boolean>
  for name, _ in pairs(target_node.chidxmap) do
    reserved[name] = true
  end

  for _, node in ipairs(selected_nodes) do
    local node_filepath = node.filepath ---@type string
    if node == self._root then
      stl.reporter.error({
        from = __module_name__,
        subject = subject,
        message = "Cannot move the root.",
      })
      return false
    end

    local parent = node.parent ---@type era.m.explorer.Node|nil
    if parent == nil then
      stl.reporter.error({
        from = __module_name__,
        subject = subject,
        message = string.format("Node '%s' is detached and cannot be moved.", node_filepath),
      })
      return false
    end

    if target_node:is_descendant_or_self(node) then
      stl.reporter.error({
        from = __module_name__,
        subject = subject,
        message = string.format(
          "Target parent '%s' is a descendant of the selected node '%s'.",
          target_parent_filepath,
          node_filepath
        ),
      })
      return false
    end

    local existing_idx = target_node.chidxmap[node.nodename] ---@type integer|nil
    if existing_idx ~= nil then
      local existing = target_node.children[existing_idx] ---@type era.m.explorer.Node
      if existing ~= node then
        stl.reporter.error({
          from = __module_name__,
          subject = subject,
          message = string.format("Target parent '%s' already contains '%s'.", target_parent_filepath, node.nodename),
        })
        return false
      end
    elseif reserved[node.nodename] then
      stl.reporter.error({
        from = __module_name__,
        subject = subject,
        message = string.format(
          "Multiple nodes named '%s' cannot be pasted into '%s'.",
          node.nodename,
          target_parent_filepath
        ),
      })
      return false
    else
      reserved[node.nodename] = true
    end
  end

  local rm = self._resource_manager ---@type era.m.explorer.resource.IManager
  local changed = false ---@type boolean

  for _, node in ipairs(selected_nodes) do
    if node.parent ~= target_node then
      local parent = node.parent ---@type era.m.explorer.Node
      local source_filepath = node.filepath ---@type string
      local destination_filepath = era.m.explorer.Node.calc_filepath(target_node_filepath, node.nodename, node.nodetype) ---@type string

      local ok, result = pcall(rm.move, rm, source_filepath, destination_filepath) ---@type boolean, boolean|nil
      if not ok then
        stl.reporter.error({
          from = __module_name__,
          subject = subject,
          message = string.format("Resource manager move failed for '%s'.", source_filepath),
          details = { target = destination_filepath, error = result },
        })
        return false
      end

      if result == false or result == nil then
        stl.reporter.error({
          from = __module_name__,
          subject = subject,
          message = string.format("Resource manager refused to move '%s'.", source_filepath),
          details = { target = destination_filepath },
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
        stl.reporter.error({
          from = __module_name__,
          subject = subject,
          message = string.format("Cannot locate node '%s' in its parent list.", source_filepath),
          details = { target = destination_filepath },
        })
        return false
      end

      table.remove(parent.children, removal_index)
      parent.chidxmap[node.nodename] = nil
      parent:sync_chidxmap(removal_index)

      node.parent = target_node
      era.m.explorer.Node.refresh_depth(node, target_node.depth + 1)
      local insert_idx = self:__find_insertion_index__(rm, target_node.children, node) ---@type integer
      table.insert(target_node.children, insert_idx, node)
      target_node:sync_chidxmap(insert_idx)

      changed = true
    end
  end

  if changed then
    self.ticks.structure = self.ticks.structure + 1
  end
  return changed
end

---@param filepath                           string
---@return boolean
function M:attach(filepath)
  self:__health__()
  filepath = normalize_dirpath(filepath)

  local rm = self._resource_manager ---@type era.m.explorer.resource.IManager
  local resource = rm:locate(filepath) ---@type era.m.explorer.resource.INode|nil
  if resource == nil then
    stl.reporter.error({
      from = __module_name__,
      subject = self.name,
      message = string.format("Failed to attach node '%s' in %s.", filepath, self.name),
    })
    return false
  end

  local node = self:__insert__(filepath, resource) ---@type era.m.explorer.Node
  node.expanded = true
  self._root = node
  self.ticks.structure = self.ticks.structure + 1
  return true
end

---@return nil
function M:clear()
  self:__health__()

  local superroot = era.m.explorer.Node.superroot() ---@type era.m.explorer.Node
  self._superroot = superroot
  self._root = superroot
  self.select_mode = "select"
  self.ticks.structure = self.ticks.structure + 1
end

---@return nil
function M:clear_selection()
  self:__health__()
  self._superroot:set_selected_recursive(false)
  self.select_mode = "select"
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

---@param filepath                           string
---@return nil
function M:expand_path(filepath)
  self:__health__()
  filepath = normalize_filepath(filepath, filepath:sub(-1) == "/")

  local root = self._root ---@type era.m.explorer.Node
  local root_filepath = root.filepath ---@type string

  if not vim.startswith(filepath, root_filepath) then
    return
  end

  local relative = filepath:sub(#root_filepath + 1) ---@type string
  local pieces = vim.split(relative, "/", { plain = true }) ---@type string[]

  local node = root ---@type era.m.explorer.Node
  local current_filepath = root_filepath ---@type string

  if not node.loaded then
    self:__load_children__(node, current_filepath)
  end

  node.expanded = true

  for _, piece in ipairs(pieces) do
    if piece == "" then
      goto continue
    end

    local idx = node.chidxmap[piece] ---@type integer|nil
    if idx == nil then
      return
    end

    node = node.children[idx]
    current_filepath = current_filepath .. piece .. (node.nodetype == "D" and "/" or "")

    if node.nodetype == "D" then
      if not node.loaded then
        self:__load_children__(node, current_filepath)
      end
      node.expanded = true
    end

    ::continue::
  end

  self.ticks.structure = self.ticks.structure + 1
end

---@param nodes                         ?era.m.explorer.Node[]
---@return string|nil
function M:get_common_ancestor_path(nodes)
  self:__health__()

  nodes = nodes or self:get_selected_nodes_toplevel()
  if #nodes == 0 then
    return nil
  end

  local paths = {} ---@type string[]
  for _, node in ipairs(nodes) do
    paths[#paths + 1] = node.filepath
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

---@return era.m.explorer.resource.IManager
function M:get_resource_manager()
  return self._resource_manager
end

---@return era.m.explorer.Node
function M:get_root_node()
  self:__health__()
  return self._root
end

---@return string
function M:get_root_filepath()
  self:__health__()
  return self._root.filepath
end

---@return era.m.explorer.Node[]
function M:get_selected_nodes()
  self:__health__()
  return era.m.explorer.Node.collect_selected(self._root)
end

---@return era.m.explorer.Node[]
function M:get_selected_nodes_toplevel()
  self:__health__()
  return era.m.explorer.Node.collect_selected_toplevel(self._root)
end

---@return string[]
function M:get_selected_filepaths()
  self:__health__()
  return era.m.explorer.Node.collect_selected_filepaths(self._root)
end

---@param parent_filepath                     string
---@param resource                      era.m.explorer.resource.INode
---@return boolean
function M:insert(parent_filepath, resource)
  self:__health__()

  local rm = self._resource_manager ---@type era.m.explorer.resource.IManager
  local resource_node = rm:locate(parent_filepath) ---@type era.m.explorer.resource.INode|nil
  if resource_node == nil then
    stl.reporter.error({
      from = __module_name__,
      subject = string.format("%s#insert", self.name),
      message = string.format("Cannot insert resource for non-existent filepath '%s'.", parent_filepath),
    })
    return false
  end

  if resource_node.nodetype ~= "D" then
    stl.reporter.error({
      from = __module_name__,
      subject = string.format("%s#insert", self.name),
      message = string.format("Cannot insert resource under non-directory filepath '%s'.", parent_filepath),
    })
    return false
  end

  local parent = self:__insert__(parent_filepath, resource_node) ---@type era.m.explorer.Node
  self:__load_children__(parent, parent_filepath)

  local idx = parent.chidxmap[resource.nodename] ---@type integer|nil
  if idx ~= nil then
    local existing = parent.children[idx] ---@type era.m.explorer.Node
    if existing.nodetype ~= resource.nodetype then
      stl.reporter.error({
        from = __module_name__,
        subject = string.format("%s#insert", self.name),
        message = string.format(
          "Cannot insert resource '%s' for filepath '%s' because a resource with the same name but different type already exists.",
          resource.nodename,
          parent_filepath
        ),
      })
      return false
    end
    return true
  end

  local children = parent.children ---@type era.m.explorer.Node[]
  local node = era.m.explorer.Node.new(parent, resource.nodetype, resource.nodename) ---@type era.m.explorer.Node
  local insert_idx = self:__find_insertion_index__(rm, children, node) ---@type integer

  table.insert(children, insert_idx, node)
  parent:sync_chidxmap(insert_idx)

  self.ticks.structure = self.ticks.structure + 1
  return true
end

---@return boolean
function M:isdisposed()
  return self._disposed
end

---@param filepath                           string
---@return boolean
function M:is_existent(filepath)
  self:__health__()
  return self:__locate__(filepath) ~= nil
end

---@param filepath                           string
---@return boolean
function M:is_expanded(filepath)
  self:__health__()
  local node = self:__locate__(filepath) ---@type era.m.explorer.Node|nil
  return node ~= nil and node.expanded
end

---@param filepath                           string
---@return boolean
function M:is_loaded(filepath)
  self:__health__()
  local node = self:__locate__(filepath) ---@type era.m.explorer.Node|nil
  return node ~= nil and node.loaded
end

---@param filepath                           string
---@return boolean
function M:is_selected(filepath)
  self:__health__()
  local node = self:__locate__(filepath) ---@type era.m.explorer.Node|nil
  return node ~= nil and node.selected
end

---@param node                          era.m.explorer.Node
---@param force                         boolean|nil
---@return nil
function M:load_node(node, force)
  self:__health__()
  local force_load = not not force ---@type boolean

  if node.nodetype ~= "D" then
    return
  end

  if not force_load and node.loaded then
    return
  end

  local filepath = node.filepath ---@type string
  self:__load_children__(node, filepath)
end

---@param filepath                           string
---@return era.m.explorer.Node|nil
function M:locate(filepath)
  self:__health__()
  return self:__locate__(filepath)
end

---@return nil
function M:mark_all_dirty()
  self:__health__()

  ---@param node                        era.m.explorer.Node
  local function mark_dirty(node)
    if node.nodetype == "D" then
      node.loaded = false
    end
    for _, child in ipairs(node.children) do
      mark_dirty(child)
    end
  end

  mark_dirty(self._superroot)
  self.ticks.structure = self.ticks.structure + 1
end

---@param force                         boolean|nil
---@return nil
function M:refresh(force)
  self:__health__()

  local force_refresh = not not force ---@type boolean
  local superroot = self._superroot ---@type era.m.explorer.Node
  local root = self._root ---@type era.m.explorer.Node
  local root_filepath = root.filepath ---@type string

  ---@param node                        era.m.explorer.Node
  ---@param nodeindex                   integer|nil
  ---@param node_filepath                     string
  local function walk(node, nodeindex, node_filepath)
    local load_node = force_refresh or not node.loaded ---@type boolean

    if node == superroot then
      if load_node then
        self:__load_children__(node, node.filepath)
      end
    elseif load_node then
      if nodeindex == nil then
        error(string.format("[refresh] Missing node index for filepath '%s'.", node_filepath))
      end
      self:__load__(node, nodeindex, node_filepath, true)
    end

    if not node.expanded then
      return
    end

    for index, child in ipairs(node.children) do
      local filepath = era.m.explorer.Node.calc_filepath(node_filepath, child.nodename, child.nodetype) ---@type string
      walk(child, index, filepath)
    end
  end

  if root == superroot then
    walk(superroot, nil, root_filepath)
    self.ticks.structure = self.ticks.structure + 1
    return
  end

  local nodeindex = root.parent.chidxmap[root.nodename] ---@type integer
  walk(root, nodeindex, root_filepath)
  self.ticks.structure = self.ticks.structure + 1
end

---@param filepath                           string
---@return boolean
function M:remove(filepath)
  self:__health__()

  local node = self:__locate__(filepath) ---@type era.m.explorer.Node|nil
  if node == nil then
    stl.reporter.warn({
      from = __module_name__,
      subject = string.format("%s#remove", self.name),
      message = string.format("Cannot remove non-existent filepath '%s'.", filepath),
    })
    return false
  end

  local superroot = self._superroot ---@type era.m.explorer.Node
  if node == superroot then
    stl.reporter.error({
      from = __module_name__,
      subject = string.format("%s#remove", self.name),
      message = "Cannot remove the superroot.",
    })
    return false
  end

  local parent = node.parent ---@type era.m.explorer.Node|nil
  if parent == nil then
    stl.reporter.error({
      from = __module_name__,
      subject = string.format("%s#remove", self.name),
      message = string.format("Detached node detected while removing '%s'.", filepath),
    })
    return false
  end

  local rm = self._resource_manager ---@type era.m.explorer.resource.IManager
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
      stl.reporter.error({
        from = __module_name__,
        subject = string.format("%s#remove", self.name),
        message = string.format("Failed to locate node '%s' during removal callback.", filepath),
      })
      return
    end

    -- Order matters:
    -- 1. table.remove: physically remove node from children array
    -- 2. sync_chidxmap: re-index remaining children after removal_index
    -- 3. chidxmap[nodename] = nil: explicitly clear the removed node's entry
    --    (sync_chidxmap only re-indexes from removal_index, it won't clear
    --    the removed node's entry if no remaining child has the same name)
    -- 4. sync_ancestors: update has_selected state along ancestor chain
    table.remove(parent.children, removal_index)
    parent:sync_chidxmap(removal_index)
    parent.chidxmap[node.nodename] = nil
    era.m.explorer.Node.sync_ancestors(parent)

    if self._root ~= nil then
      if self._root:is_descendant_or_self(node) then
        self._root = parent
      end
    end

    node.parent = nil
    node.children = {}
    node.chidxmap = {}
    node.depth = 0

    removed = true
  end

  local ok, result = pcall(rm.remove, rm, filepath, on_removed) ---@type boolean, boolean|nil
  if not ok then
    stl.reporter.error({
      from = __module_name__,
      subject = string.format("%s#remove", self.name),
      message = string.format("Resource manager removal failed for '%s': %s", filepath, result),
    })
    return false
  end

  if result == false then
    stl.reporter.error({
      from = __module_name__,
      subject = string.format("%s#remove", self.name),
      message = string.format("Resource manager refused to remove '%s'.", filepath),
    })
    return false
  end

  self.ticks.structure = self.ticks.structure + 1
  return result ~= false
end

---@param filepath                           string
---@param recursive                     boolean
---@param force_expanded                era.m.explorer.ForceExpandedEnum|nil
---@return nil
function M:toggle_expanded(filepath, recursive, force_expanded)
  self:__health__()
  local node = self:__locate__(filepath) ---@type era.m.explorer.Node|nil
  if node == nil then
    return
  end

  local expanded ---@type boolean
  if force_expanded == "expand" then
    expanded = true
  elseif force_expanded == "collapse" then
    expanded = false
  else
    expanded = not node.expanded
  end

  if recursive then
    node:set_expanded_recursive(expanded)
  else
    node.expanded = expanded
  end

  self.ticks.structure = self.ticks.structure + 1
end

---@param filepath                           string
---@param force_selected                era.m.explorer.ForceSelectedEnum|nil
---@return nil
function M:toggle_selected(filepath, force_selected)
  self:__health__()
  local node = self:__locate__(filepath) ---@type era.m.explorer.Node|nil
  if node == nil then
    return
  end

  local selected ---@type boolean
  if force_selected == "select" then
    selected = true
  elseif force_selected == "unselect" then
    selected = false
  else
    selected = not node.selected
  end

  self:__load_subtree__(node)
  node:set_selected_recursive(selected)
  era.m.explorer.Node.sync_ancestors(node)
end

----------------------------------------------------------------------------------------------------

---@protected
---@param node                          era.m.explorer.Node
---@return nil
function M:__load_subtree__(node)
  if node.nodetype == "F" then
    return
  end

  if not node.loaded then
    self:__load_children__(node, node.filepath)
  end

  for _, child in ipairs(node.children) do
    self:__load_subtree__(child)
  end
end

---@protected
---@param filepath                           string
---@return era.m.explorer.NodeTypeEnum
function M:__detect_nodetype__(filepath)
  local nodetype = filepath:sub(-1) == "/" and "D" or "F" ---@type era.m.explorer.NodeTypeEnum
  return nodetype
end

---@protected
---@param resource_manager              era.m.explorer.resource.IManager
---@param children                      era.m.explorer.Node[]
---@param candidate                     era.m.explorer.Node
---@return integer
function M:__find_insertion_index__(resource_manager, children, candidate)
  local lo = 1 ---@type integer
  local hi = #children ---@type integer
  while lo <= hi do
    local mid = math.floor((lo + hi) / 2) ---@type integer
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
---@return nil
function M:__health__()
  if self._disposed then
    local message = string.format("%s has been disposed.", self.name) ---@type string
    error(message)
  end
end

---@protected
---@param filepath                           string
---@param resource                      era.m.explorer.resource.INode|nil
---@param ensure_resource               boolean|nil
---@return era.m.explorer.Node
---@return boolean
function M:__insert__(filepath, resource, ensure_resource)
  filepath = normalize_filepath(filepath, filepath:sub(-1) == "/")

  local superroot = self._superroot ---@type era.m.explorer.Node
  local superroot_filepath = superroot.filepath ---@type string
  if superroot_filepath == filepath then
    return superroot, false
  end

  local rm = self._resource_manager ---@type era.m.explorer.resource.IManager
  local ensure_created = ensure_resource == true ---@type boolean
  if resource == nil then
    if ensure_created then
      if rm:insert_if_missing(filepath) == false then
        local message = string.format("Failed to create node filepath: '%s'.", filepath) ---@type string
        error(message)
      end
      resource = rm:locate(filepath) ---@type era.m.explorer.resource.INode|nil
      if resource == nil then
        local message = string.format("Failed to locate node filepath after creation: '%s'.", filepath) ---@type string
        error(message)
      end
    else
      resource = rm:locate(filepath) ---@type era.m.explorer.resource.INode|nil
      if resource == nil then
        local message = string.format("Cannot materialize non-existent node filepath: '%s'.", filepath) ---@type string
        error(message)
      end
    end
  end

  local Ns = #superroot_filepath ---@type integer
  local Nn = #filepath ---@type integer
  if Nn <= Ns then
    local message = string.format("Invalid node filepath: '%s'. Must be descendant of the superroot", filepath) ---@type string
    error(message)
  end

  local nodetype = resource ~= nil and resource.nodetype or self:__detect_nodetype__(filepath) ---@type era.m.explorer.NodeTypeEnum
  local pieces = split_path_pieces(filepath:sub(Ns + 1)) ---@type string[]

  local o = superroot ---@type era.m.explorer.Node
  local n = #pieces ---@type integer

  if n == 0 then
    return superroot, false
  end

  local new_created = false ---@type boolean

  for i = 1, n, 1 do
    local piece = pieces[i] ---@type string

    local idx = o.chidxmap[piece] ---@type integer|nil
    if idx == nil then
      local child_nodetype = i == n and nodetype or "D" ---@type era.m.explorer.NodeTypeEnum
      local child = era.m.explorer.Node.new(o, child_nodetype, piece) ---@type era.m.explorer.Node
      local insert_idx = self:__find_insertion_index__(rm, o.children, child) ---@type integer

      table.insert(o.children, insert_idx, child)
      o:sync_chidxmap(insert_idx)

      o = child
      new_created = true
    else
      o = o.children[idx] ---@type era.m.explorer.Node
    end
  end
  o.filepath = era.m.explorer.Node.calc_filepath(o.parent.filepath, o.nodename, o.nodetype)
  return o, new_created
end

---@protected
---@param node                          era.m.explorer.Node
---@param nodeindex                     integer
---@param filepath                           string
---@param force                         boolean
---@return era.m.explorer.Node
function M:__load__(node, nodeindex, filepath, force)
  local superroot = self._superroot ---@type era.m.explorer.Node

  if node == superroot then
    if force or not node.loaded then
      self:__load_children__(node, filepath)
    end
    return node
  end

  local rm = self._resource_manager ---@type era.m.explorer.resource.IManager
  local resource_node = rm:locate(filepath) ---@type era.m.explorer.resource.INode|nil
  if resource_node == nil then
    local message = string.format("[__load__] Failed to load non-existent node filepath: '%s'.", filepath) ---@type string
    error(message)
  end

  if node.nodetype ~= resource_node.nodetype then
    local parent = node.parent ---@type era.m.explorer.Node|nil
    if parent == nil then
      error(string.format("[__load__] Parent is nil for node filepath: '%s'.", filepath))
    end

    ---@type era.m.explorer.Node
    local new_node = setmetatable({
      filepath = filepath,
      nodename = resource_node.nodename,
      nodetype = resource_node.nodetype,
      parent = parent,
      children = {},
      chidxmap = {},
      depth = parent.depth + 1,
      expanded = node.expanded,
      loaded = resource_node.nodetype == "F",
      selected = parent.selected,
      has_selected = parent.selected,
    }, era.m.explorer.Node)

    node.parent.children[nodeindex] = new_node

    if resource_node.nodetype == "D" then
      self:__load_children__(new_node, filepath)
    end
    return new_node
  end

  node.filepath = filepath

  if node.nodetype == "F" then
    node.loaded = true
    return node
  end

  if not force and node.loaded then
    return node
  end

  self:__load_children__(node, filepath)
  return node
end

---@protected
---@param node                          era.m.explorer.Node
---@param filepath                           string
---@return nil
function M:__load_children__(node, filepath)
  local rm = self._resource_manager ---@type era.m.explorer.resource.IManager
  local items = rm:load(filepath) ---@type era.m.explorer.resource.INode[]

  local base_filepath = node.filepath ---@type string
  for _, item in ipairs(items) do
    if item.filepath == nil then
      item.filepath = era.m.explorer.Node.calc_filepath(base_filepath, item.nodename, item.nodetype)
    end
  end

  local children = node.children ---@type era.m.explorer.Node[]
  local chidxmap = node.chidxmap ---@type table<string, integer|nil>
  local child_count = #children ---@type integer
  local item_count = #items ---@type integer

  local unchanged = child_count == item_count ---@type boolean
  if unchanged and child_count > 0 then
    for index = 1, child_count, 1 do
      local child = children[index] ---@type era.m.explorer.Node|nil
      local item = items[index] ---@type era.m.explorer.resource.INode
      if child == nil or child.nodename ~= item.nodename or child.nodetype ~= item.nodetype then
        unchanged = false
        break
      end
    end
  end

  if unchanged then
    -- When children are unchanged:
    -- - node.filepath hasn't changed (same directory)
    -- - chidxmap indices are already correct
    -- - child.filepath doesn't need recalculation
    -- Only need to ensure node.loaded is set
    node.loaded = true
    return
  end

  local new_children = {} ---@type era.m.explorer.Node[]
  local new_chidxmap = {} ---@type table<string, integer|nil>
  for i, item in ipairs(items) do
    local old_index = chidxmap[item.nodename] ---@type integer|nil
    local old_child = old_index ~= nil and children[old_index] or nil ---@type era.m.explorer.Node|nil
    if old_child == nil or old_child.nodetype ~= item.nodetype then
      local child = era.m.explorer.Node.new(node, item.nodetype, item.nodename) ---@type era.m.explorer.Node
      child.filepath = era.m.explorer.Node.calc_filepath(node.filepath, child.nodename, child.nodetype)
      new_children[i] = child
      new_chidxmap[item.nodename] = i
    else
      old_child.parent = node
      old_child.filepath = era.m.explorer.Node.calc_filepath(node.filepath, old_child.nodename, old_child.nodetype)
      if old_child.nodetype == "F" then
        old_child.loaded = true
      end
      new_children[i] = old_child
      new_chidxmap[item.nodename] = i
    end
  end
  node.children = new_children
  node.chidxmap = new_chidxmap
  node.loaded = true
end

---@protected
---@param filepath                           string
---@return era.m.explorer.Node|nil
function M:__locate__(filepath)
  filepath = normalize_filepath(filepath, filepath:sub(-1) == "/")

  local superroot = self._superroot ---@type era.m.explorer.Node
  local superroot_filepath = superroot.filepath ---@type string
  if superroot_filepath == filepath then
    return superroot
  end

  local Ns = #superroot_filepath ---@type integer
  local Nn = #filepath ---@type integer
  if Nn <= Ns then
    return nil
  end

  local o = superroot ---@type era.m.explorer.Node
  local pieces = split_path_pieces(filepath:sub(Ns + 1)) ---@type string[]

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
    o = o.children[idx] ---@type era.m.explorer.Node
  end
  return o
end

return M
