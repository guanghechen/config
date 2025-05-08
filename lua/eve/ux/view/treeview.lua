local __module_name__ = "eve.ux.view.treeview" ---@type string

---@alias eve.ux.view.treeview.NodeTypeEnum
---| 'container'
---| 'leaf'

---@alias eve.ux.view.treeview.INode
---| eve.ux.view.treeview.IContainerNode
---| eve.ux.view.treeview.ILeafNode

---@alias eve.ux.view.treeview.INodeRenderer
---| fun(node: eve.ux.view.treeview.INode): string, eve.t.IHighlightInline[]|nil

---@alias eve.ux.view.treeview.INodeSorter
---| fun(left: eve.ux.view.treeview.INode, right: eve.ux.view.treeview.INode): boolean

---@class eve.ux.view.treeview.IContainerNode
---@field public type                   'container'
---@field public uuid                   string
---@field public parent                 string
---@field public data                   unknown
---@field public text                   string|nil
---@field public highlights             eve.t.IHighlightInline[]|nil
---@field public collapsed              boolean
---@field public dirty_orders           boolean
---@field public children               string[]

---@class eve.ux.view.treeview.ILeafNode
---@field public type                   'leaf'
---@field public uuid                   string
---@field public parent                 string
---@field public data                   unknown
---@field public text                   string|nil
---@field public highlights             eve.t.IHighlightInline[]|nil

---@class eve.ux.view.ITreeviewProps
---@field public name                   string
---@field public nsnr                   ?integer
---@field public indent                 ?string
---@field public indent_hln             ?string
---@field public renderer               eve.ux.view.treeview.INodeRenderer
---@field public sorter                 eve.ux.view.treeview.INodeSorter

---@class eve.ux.view.Treeview : eve.ux.view.IView
---@field protected _disposed           boolean
---@field protected _indent             string
---@field protected _indent_hln         string
---@field protected _lnum2uuid          table<integer, string>
---@field protected _uuid2lnum          table<string, integer>
---@field protected _node_map           table<string, eve.ux.view.treeview.INode>
---@field protected _node_root          eve.ux.view.treeview.IContainerNode
---@field protected _renderer           eve.ux.view.treeview.INodeRenderer
---@field protected _sorter             eve.ux.view.treeview.INodeSorter
local M = {}
M.__index = M

local NSNR_DEFAULT = vim.api.nvim_create_namespace("ux_view_treeview") ---@type integer

---@param props                         eve.ux.view.ITreeviewProps
---@return eve.ux.view.Treeview
function M.new(props)
  local name = props.name ---@type string
  local nsnr = props.nsnr or NSNR_DEFAULT ---@type integer
  local indent = props.indent or "  " ---@type string
  local indent_hln = props.indent_hln or "f_utw_indent" ---@type string
  local renderer = props.renderer ---@type eve.ux.view.treeview.INodeRenderer
  local sorter = props.sorter ---@type eve.ux.view.treeview.INodeSorter

  local self = setmetatable({}, M)

  ---@type eve.ux.view.treeview.IContainerNode
  local root = {
    type = "container",
    parent = "__virtual_root__",
    uuid = "__virtual_root__",
    data = nil,
    collapsed = false,
    dirty_orders = false,
    children = {},
  }

  self.name = name
  self.nsnr = nsnr
  self._disposed = false
  self._indent = indent
  self._indent_hln = indent_hln
  self._lnum2uuid = {}
  self._uuid2lnum = {}
  self._node_map = { [root.uuid] = root }
  self._node_root = root
  self._renderer = renderer
  self._sorter = sorter
  return self
end

---@return eve.ux.view.Treeview
function M:clear()
  self:health()

  local root = self._node_root ---@type eve.ux.view.treeview.IContainerNode
  self._lnum2uuid = {}
  self._uuid2lnum = {}
  self._node_map = { [root.uuid] = root }
  self._node_root.children = {}
  self._node_root.dirty_orders = false
  return self
end

---@return nil
function M:dispose()
  if self._disposed then
    return nil
  end

  self._disposed = true
  self._indent = nil
  self._lnum2uuid = nil
  self._uuid2lnum = nil
  self._node_map = nil
  self._node_root = nil
  self._renderer = nil
  self._sorter = nil
end

---@return boolean
function M:isdisposed()
  return self._disposed
end

---@return nil
function M:health()
  if self._disposed then
    local message = string.format("Treeview (%s) has been disposed.", self.name) ---@type string
    error(message)
  end
end

---@param root_uuid                     string|nil
---@param included_uuid_set             table<string, boolean>|nil
---@return integer
---@return integer
function M:measure(root_uuid, included_uuid_set)
  self:health()

  local root = (root_uuid ~= nil and self._node_map[root_uuid]) or self._node_root
  if root.type ~= "container" then
    eve.reporter.error({
      from = __module_name__,
      subject = "measure",
      message = "The root node is not a container node",
      details = { root_uuid = root_uuid, included_uuid_set = included_uuid_set },
    })
    return 0, 0
  end

  if included_uuid_set ~= nil and not included_uuid_set[root.uuid] then
    return 0, 0
  end

  local node_map = self._node_map ---@type table<string, eve.ux.view.treeview.INode>

  local height = 0 ---@type integer
  local max_width = vim.api.nvim_strwidth(self._indent) ---@type integer
  local INDENT_WIDTH_UINT = 2 ---@type integer
  local recursive ---@type fun(parent: eve.ux.view.treeview.IContainerNode, depth: integer, indent_width: integer): nil

  ---@param uuid                        string
  ---@param next_depth                  integer
  ---@param indent_width                integer
  ---@param next_indent_width           integer
  ---@return nil
  local function measure(uuid, next_depth, indent_width, next_indent_width)
    local node = node_map[uuid] ---@type eve.ux.view.treeview.INode
    if node.text == nil then
      local text, highlights = self._renderer(node)
      node.text = text
      node.highlights = highlights
    end
    height = height + 1 ---@type integer
    max_width = math.max(max_width, indent_width + vim.api.nvim_strwidth(node.text)) ---@type integer

    if node.type == "container" and not node.collapsed then
      recursive(node, next_depth, next_indent_width) ---@type integer, integer
    end
  end

  if included_uuid_set == nil then
    ---@param parent                    eve.ux.view.treeview.IContainerNode
    ---@param depth                     integer
    ---@param indent_width              integer
    ---@return nil
    recursive = function(parent, depth, indent_width)
      local next_depth = depth + 1 ---@type integer
      local next_indent_width = indent_width + INDENT_WIDTH_UINT ---@type integer
      for _, uuid in ipairs(parent.children) do
        measure(uuid, next_depth, indent_width, next_indent_width)
      end
    end
  else
    ---@param parent                    eve.ux.view.treeview.IContainerNode
    ---@param depth                     integer
    ---@param indent_width              integer
    ---@return nil
    recursive = function(parent, depth, indent_width)
      local next_depth = depth + 1 ---@type integer
      local next_indent_width = indent_width + 2 ---@type integer
      for _, uuid in ipairs(parent.children) do
        if included_uuid_set[uuid] then
          measure(uuid, next_depth, indent_width, next_indent_width)
        end
      end
    end
  end

  recursive(root, 0, INDENT_WIDTH_UINT)
  return height, max_width
end

---@param bufnr                         integer
---@param root_uuid                     string|nil
---@param included_uuid_set             table<string, boolean>|nil
---@return eve.ux.view.Treeview
function M:render(bufnr, root_uuid, included_uuid_set)
  self:health()

  local root = (root_uuid ~= nil and self._node_map[root_uuid]) or self._node_root
  if root.type ~= "container" then
    eve.reporter.error({
      from = __module_name__,
      subject = "measure",
      message = "The root node is not a container node",
      details = { root_uuid = root_uuid, included_uuid_set = included_uuid_set },
    })
    return self
  end

  local nsnr = self.nsnr ---@type integer
  self._lnum2uuid = {} ---@type table<integer, string>
  self._uuid2lnum = {} ---@type table<string, integer>

  if included_uuid_set ~= nil and not included_uuid_set[root.uuid] then
    vim.api.nvim_buf_clear_namespace(bufnr, nsnr, 0, -1)
    vim.api.nvim_buf_set_lines(bufnr, 0, -1, false, {})
    return self
  end

  local lnum2uuid = self._lnum2uuid ---@type table<integer, string>
  local uuid2lnum = self._uuid2lnum ---@type table<string, integer>
  local node_map = self._node_map ---@type table<string, eve.ux.view.treeview.INode>

  local row = 0 ---@type integer
  local recursive ---@type fun(parent: eve.ux.view.treeview.IContainerNode, depth: integer, indent: string): nil

  ---@param uuid                        string
  ---@param next_depth                  integer
  ---@param indent                      string
  ---@param next_indent                 string
  ---@return nil
  local function render(uuid, next_depth, indent, next_indent)
    local node = node_map[uuid] ---@type eve.ux.view.treeview.INode
    if node.text == nil then
      local text, highlights = self._renderer(node)
      node.text = text
      node.highlights = highlights
    end

    local lnum = row + 1 ---@type integer
    lnum2uuid[lnum] = node.uuid
    uuid2lnum[node.uuid] = lnum

    local text = indent .. node.text ---@type string
    vim.api.nvim_buf_set_lines(bufnr, row, lnum, false, { text })

    if node.highlights ~= nil then
      local offset = #indent ---@type integer
      vim.hl.range(bufnr, nsnr, self._indent_hln, { row, 0 }, { row, offset })
      for _, highlight in ipairs(node.highlights) do
        local hlname = highlight.hlname ---@type string
        local colr = highlight.colr ---@type integer
        local coll = highlight.coll ---@type integer
        vim.hl.range(bufnr, nsnr, hlname, { row, offset + coll }, { row, offset + colr })
      end
    end

    row = row + 1 ---@type integer
    if node.type == "container" and not node.collapsed then
      if not node.collapsed then
        recursive(node, next_depth, next_indent)
      end
    end
  end

  if included_uuid_set == nil then
    ---@param parent                    eve.ux.view.treeview.IContainerNode
    ---@param depth                     integer
    ---@param indent                    string
    ---@return nil
    recursive = function(parent, depth, indent)
      local N = #parent.children ---@type integer
      if N < 1 then
        return
      end

      local next_depth = depth + 1 ---@type integer
      local child_nested_indent = indent .. "│ " ---@type string
      local last_child_nested_indent = indent .. "  " ---@type string
      local child_indent = indent .. "├─" ---@type string
      local last_child_indent = indent .. "╰─" ---@type string

      if parent.dirty_orders then
        self:sort_container_node(parent)
      end

      for index = 1, N - 1, 1 do
        local uuid = parent.children[index] ---@type string
        render(uuid, next_depth, child_indent, child_nested_indent)
      end
      local uuid = parent.children[N] ---@type string
      render(uuid, next_depth, last_child_indent, last_child_nested_indent)
    end
  else
    ---@param parent                    eve.ux.view.treeview.IContainerNode
    ---@param depth                     integer
    ---@param indent                    string
    ---@return nil
    recursive = function(parent, depth, indent)
      local N = -1 ---@type integer
      for index = #parent.children, 1, -1 do
        local uuid = parent.children[index] ---@type string
        if included_uuid_set[uuid] then
          N = index
          break
        end
      end

      if N < 1 then
        return
      end

      local next_depth = depth + 1 ---@type integer
      local child_nested_indent = indent .. "│ " ---@type string
      local last_child_nested_indent = indent .. "  " ---@type string
      local child_indent = indent .. "├─" ---@type string
      local last_child_indent = indent .. "╰─" ---@type string

      if parent.dirty_orders then
        self:sort_container_node(parent)
      end

      for index = 1, N - 1, 1 do
        local uuid = parent.children[index] ---@type string
        if included_uuid_set[uuid] then
          render(uuid, next_depth, child_indent, child_nested_indent)
        end
      end
      local uuid = parent.children[N] ---@type string
      render(uuid, next_depth, last_child_indent, last_child_nested_indent)
    end
  end

  vim.api.nvim_buf_clear_namespace(bufnr, nsnr, 0, -1)
  recursive(root, 0, self._indent)
  vim.api.nvim_buf_set_lines(bufnr, row, -1, false, {})
  return self
end

----------------------------------------------------------------------------------------------------

---@param included_uuids                string[]
---@return table<string, boolean>
function M:calc_include_uuid_set(included_uuids)
  self:health()

  local uuids = {} ---@type table<string, boolean>
  local node_map = self._node_map ---@type table<string, eve.ux.view.treeview.INode>
  for _, uuid in ipairs(included_uuids) do
    local node = node_map[uuid] ---@type eve.ux.view.treeview.INode|nil
    if node == nil then
      eve.reporter.warn({
        from = __module_name__,
        subject = "calc_include_uuid_set",
        message = "The node isn't exist",
        details = { uuid = uuid },
      })
      goto continue
    end

    uuids[uuid] = true

    while not uuids[node.parent] do
      uuids[node.parent] = true
      node = node_map[node.parent]
    end

    ::continue::
  end
  return uuids
end

---@param uuid                          string
---@param value                         "collapsed"|"expanded"|"toggle"
---@param recursive                     ?boolean
---@return eve.ux.view.Treeview
function M:collapse(uuid, value, recursive)
  self:health()

  local node = self._node_map[uuid] ---@type eve.ux.view.treeview.INode|nil
  if node == nil then
    eve.reporter.error({
      from = __module_name__,
      subject = "collapse",
      message = "The node isn't exist",
      details = { uuid = uuid, value = value, recursive = recursive },
    })
    return self
  end

  if node.type ~= "container" then
    eve.reporter.warn({
      from = __module_name__,
      subject = "collapse (ignored)",
      message = "The node is not a container node",
      details = { uuid = uuid, value = value, recursive = recursive },
    })
    return self
  end

  local collapsed = node.collapsed ---@type boolean
  if value == "toggle" then
    collapsed = not collapsed
  elseif value == "collapsed" then
    collapsed = true
  elseif value == "expanded" then
    collapsed = false
  end

  node.collapsed = collapsed
  node.text = nil
  node.highlights = nil
  if recursive then
    self:update_collapse_recursively(node, collapsed)
  end
  return self
end

---@param uuid                          string
---@return boolean
function M:has(uuid)
  self:health()
  return self._node_map[uuid] ~= nil
end

---@param uuid                          string
---@param parent_uuid                   string
---@param data                          unknown
---@param collapsed                     ?boolean
---@return eve.ux.view.Treeview
function M:insert_container(uuid, parent_uuid, data, collapsed)
  self:health()

  local node_map = self._node_map ---@type table<string, eve.ux.view.treeview.INode>

  local node = node_map[uuid] ---@type eve.ux.view.treeview.INode|nil
  if node ~= nil then
    return self:update_container(uuid, parent_uuid, data, collapsed)
  end

  local parent = self:retrieve_parent(uuid, parent_uuid) ---@type eve.ux.view.treeview.IContainerNode|nil
  if parent == nil then
    return self
  end

  ---@type eve.ux.view.treeview.IContainerNode
  local new_node = {
    type = "container",
    uuid = uuid,
    parent = parent_uuid,
    data = data,
    collapsed = collapsed == true,
    dirty_orders = false,
    children = {},
  }

  parent.children[#parent.children + 1] = uuid
  parent.dirty_orders = true
  node_map[uuid] = new_node
  return self
end

---@param uuid                          string
---@param parent_uuid                   string
---@param data                          unknown
---@return eve.ux.view.Treeview
function M:insert_leaf(uuid, parent_uuid, data)
  self:health()

  local node_map = self._node_map ---@type table<string, eve.ux.view.treeview.INode>

  local old_node = node_map[uuid] ---@type eve.ux.view.treeview.INode|nil
  if old_node ~= nil then
    return self:update_leaf(uuid, parent_uuid, data)
  end

  local parent = self:retrieve_parent(uuid, parent_uuid) ---@type eve.ux.view.treeview.IContainerNode|nil
  if parent == nil then
    return self
  end

  ---@type eve.ux.view.treeview.ILeafNode
  local new_node = {
    type = "leaf",
    uuid = uuid,
    parent = parent_uuid,
    data = data,
  }

  parent.children[#parent.children + 1] = uuid
  parent.dirty_orders = true
  node_map[uuid] = new_node
  return self
end

---@param uuid                          string
---@return eve.ux.view.Treeview
function M:remove(uuid)
  self:health()

  local node_map = self._node_map ---@type table<string, eve.ux.view.treeview.INode>
  local node = node_map[uuid] ---@type eve.ux.view.treeview.INode|nil

  if node == nil then
    eve.reporter.error({
      from = __module_name__,
      subject = "remove",
      message = "The node isn't exist",
      details = { uuid = uuid },
    })
    return self
  end

  local parent = self:retrieve_parent(uuid, node.parent) ---@type eve.ux.view.treeview.IContainerNode|nil
  if parent == nil then
    return self
  end

  parent.children = vim.tbl_filter(function(child_uuid)
    return child_uuid ~= uuid
  end, parent.children)

  node_map[uuid] = nil
  if node.type == "container" then
    self:remove_recursively(node)
  end

  return self
end

---@param lnum                          integer
---@param silent                        boolean|nil
---@return eve.ux.view.treeview.INode|nil
function M:retrieve_by_lnum(lnum, silent)
  self:health()

  local uuid = self._lnum2uuid[lnum] ---@type string|nil
  if uuid == nil then
    if not silent then
      eve.reporter.error({
        from = __module_name__,
        subject = "retrieve_by_lnum",
        message = "Cannot retrieve the uuid by the given lnum",
        details = { lnum = lnum },
      })
    end
    return nil
  end

  local node_map = self._node_map ---@type table<string, eve.ux.view.treeview.INode>
  local node = node_map[uuid] ---@type eve.ux.view.treeview.INode|nil

  if node == nil then
    if not silent then
      eve.reporter.error({
        from = __module_name__,
        subject = "retrieve_by_lnum",
        message = "The node isn't exist",
        details = { lnum = lnum, uuid = uuid },
      })
    end
    return nil
  end
  return node
end

---@param uuid                          string
---@param silent                        boolean|nil
---@return eve.ux.view.treeview.INode|nil
function M:retrieve_by_uuid(uuid, silent)
  self:health()

  local node_map = self._node_map ---@type table<string, eve.ux.view.treeview.INode>
  local node = node_map[uuid] ---@type eve.ux.view.treeview.INode|nil

  if node == nil then
    if not silent then
      eve.reporter.error({
        from = __module_name__,
        subject = "retrieve_by_uuid",
        message = "The node isn't exist",
        details = { uuid = uuid },
      })
    end
    return nil
  end
  return node
end

---@param uuid                          string
---@return integer|nil
function M:retrieve_lnum(uuid)
  self:health()
  return self._uuid2lnum[uuid] ---@type integer|nil
end

---@param uuid                          string
---@param parent_uuid                   string|nil
---@param data                          unknown
---@param collapsed                     ?boolean
---@param insert_if_non_exist           ?boolean
---@return eve.ux.view.Treeview
function M:update_container(uuid, parent_uuid, data, collapsed, insert_if_non_exist)
  self:health()

  local node_map = self._node_map ---@type table<string, eve.ux.view.treeview.INode>

  local node = node_map[uuid] ---@type eve.ux.view.treeview.INode|nil
  if node == nil then
    if not insert_if_non_exist then
      eve.reporter.error({
        from = __module_name__,
        subject = "update_container (ignored)",
        message = "The node isn't exist",
        details = { uuid = uuid, parent_uuid = parent_uuid, data = data, collapsed = collapsed },
      })
      return self
    end

    if parent_uuid == nil then
      eve.reporter.error({
        from = __module_name__,
        subject = "update_container (ignored)",
        message = "The node isn't exist and the parent_uuid not provided",
        details = { uuid = uuid, parent_uuid = parent_uuid, data = data, collapsed = collapsed },
      })
      return self
    end

    return self:insert_container(uuid, parent_uuid, data, collapsed)
  end

  if node.type ~= "container" then
    eve.reporter.warn({
      from = __module_name__,
      subject = "update_container (ignored)",
      message = "The exists node is not a container node",
      details = { uuid = uuid, parent_uuid = parent_uuid, data = data, collapsed = collapsed, old_node = node },
    })
    return self
  end

  node.text = nil
  node.highlights = nil

  parent_uuid = parent_uuid or node.parent ---@type string
  if node.parent == parent_uuid then
    node.data = data
    if collapsed ~= nil then
      node.collapsed = collapsed ---@type boolean
    end
    return self
  end

  local old_parent_node = self:retrieve_parent(uuid, node.parent) ---@type eve.ux.view.treeview.IContainerNode|nil
  if old_parent_node == nil then
    return self
  end

  local parent = self:retrieve_parent(uuid, parent_uuid) ---@type eve.ux.view.treeview.IContainerNode|nil
  if parent == nil then
    return self
  end

  old_parent_node.children = vim.tbl_filter(function(child_uuid)
    return child_uuid ~= uuid
  end, old_parent_node.children)

  if collapsed ~= nil then
    node.collapsed = collapsed ---@type boolean
  end
  node.data = data
  node.parent = parent_uuid
  parent.children[#parent.children + 1] = uuid
  parent.dirty_orders = true
  return self
end

---@param uuid                          string
---@param parent_uuid                   string|nil
---@param data                          unknown
---@param insert_if_non_exist           boolean|nil
---@return eve.ux.view.Treeview
function M:update_leaf(uuid, parent_uuid, data, insert_if_non_exist)
  self:health()

  local node_map = self._node_map ---@type table<string, eve.ux.view.treeview.INode>

  local node = node_map[uuid] ---@type eve.ux.view.treeview.INode|nil
  if node == nil then
    if not insert_if_non_exist then
      eve.reporter.error({
        from = __module_name__,
        subject = "update_leaf (ignored)",
        message = "The node isn't exist",
        details = { uuid = uuid, parent_uuid = parent_uuid, data = data },
      })
      return self
    end

    if parent_uuid == nil then
      eve.reporter.error({
        from = __module_name__,
        subject = "update_leaf (ignored)",
        message = "The node isn't exist and the parent_uuid not provided",
        details = { uuid = uuid, parent_uuid = parent_uuid, data = data },
      })
      return self
    end

    return self:insert_leaf(uuid, parent_uuid, data)
  end

  if node.type ~= "leaf" then
    eve.reporter.warn({
      from = __module_name__,
      subject = "update_leaf (ignored)",
      message = "The exists node is not a leaf node",
      details = { uuid = uuid, parent_uuid = parent_uuid, data = data, old_node = node },
    })
    return self
  end

  node.text = nil
  node.highlights = nil

  parent_uuid = parent_uuid or node.parent ---@type string
  if node.parent == parent_uuid then
    node.data = data
    return self
  end

  local old_parent_node = self:retrieve_parent(uuid, node.parent) ---@type eve.ux.view.treeview.IContainerNode|nil
  if old_parent_node == nil then
    return self
  end

  local parent = self:retrieve_parent(uuid, parent_uuid) ---@type eve.ux.view.treeview.IContainerNode|nil
  if parent == nil then
    return self
  end

  old_parent_node.children = vim.tbl_filter(function(child_uuid)
    return child_uuid ~= uuid
  end, old_parent_node.children)

  node.data = data
  node.parent = parent_uuid
  parent.children[#parent.children + 1] = uuid
  parent.dirty_orders = true
  return self
end

----------------------------------------------------------------------------------------------------

---@protected
---@param parent                        eve.ux.view.treeview.IContainerNode
---@return nil
function M:remove_recursively(parent)
  local node_map = self._node_map ---@type table<string, eve.ux.view.treeview.INode>
  for _, uuid in ipairs(parent.children) do
    local child = node_map[uuid] ---@type eve.ux.view.treeview.INode
    node_map[uuid] = nil
    if child.type == "container" then
      self:remove_recursively(child)
    end
  end
end

---@param parent                        eve.ux.view.treeview.IContainerNode
---@param depth                         integer
---@param lnum                          integer
---@param bufnr                         integer
---@param included_uuid_set             table<string, boolean>|nil
---@return integer
function M:render_recursively(parent, depth, lnum, bufnr, included_uuid_set)
  local lnum2uuid = self._lnum2uuid ---@type table<integer, string>
  local uuid2lnum = self._uuid2lnum ---@type table<string, integer>

  local next_depth = depth + 1 ---@type integer
  local indent = string.rep(" ", depth * 2) ---@type string
  local offset = #indent + 2 ---@type integer

  if parent.dirty_orders then
    self:sort_container_node(parent)
  end

  for _, uuid in ipairs(parent.children) do
    local child = self._node_map[uuid] ---@type eve.ux.view.treeview.INode
    if child.text == nil then
      local text, highlights = self._renderer(child)
      child.text = text
      child.highlights = highlights
    end

    local collapsed = " " ---@type string
    if child.type == "container" and #child.children > 0 then
      collapsed = child.collapsed and eve.icon.fillchars.foldclose or eve.icon.fillchars.foldopen ---@type string
    end
    local text = string.format("%s%s %s", indent, collapsed, child.text) ---@type string

    local row = lnum - 1 ---@type integer
    lnum2uuid[lnum] = child.uuid
    uuid2lnum[child.uuid] = lnum
    vim.api.nvim_buf_set_lines(bufnr, row, lnum, false, { text })

    if child.highlights ~= nil then
      for _, highlight in ipairs(child.highlights) do
        local hlname = highlight.hlname ---@type string
        local colr = highlight.colr ---@type integer
        local coll = highlight.coll ---@type integer
        vim.hl.range(bufnr, self.nsnr, hlname, { row, offset + coll }, { row, offset + colr })
      end
    end

    lnum = lnum + 1 ---@type integer

    if child.type == "container" and not child.collapsed then
      if not child.collapsed then
        lnum = self:render_recursively(child, next_depth, lnum, bufnr, included_uuid_set)
      end
    end
  end
  return lnum
end

---@protected
---@param uuid                          string
---@param parent_uuid                   string
---@return eve.ux.view.treeview.IContainerNode|nil
function M:retrieve_parent(uuid, parent_uuid)
  if uuid == parent_uuid then
    return self._node_root
  end

  local parent = self._node_map[parent_uuid] ---@type eve.ux.view.treeview.INode|nil
  if parent == nil or parent.type ~= "container" then
    eve.reporter.error({
      from = __module_name__,
      subject = "retrieve_parent",
      message = "The expected parent is not a valid container node.",
      details = { uuid = uuid, parent_uuid = parent_uuid },
    })
    return nil
  end
  return parent
end

---@protected
---@param parent                        eve.ux.view.treeview.IContainerNode
---@return nil
function M:sort_container_node(parent)
  parent.dirty_orders = false
  if #parent.children > 1 then
    table.sort(parent.children, function(uuid_left, uuid_right)
      local left_node = self._node_map[uuid_left] ---@type eve.ux.view.treeview.INode
      local right_node = self._node_map[uuid_right] ---@type eve.ux.view.treeview.INode
      if left_node.type == right_node.type then
        return self._sorter(left_node, right_node)
      end
      return left_node.type == "container"
    end)
  end
end

---@protected
---@param parent                        eve.ux.view.treeview.IContainerNode
---@param collapsed                     boolean
---@return nil
function M:update_collapse_recursively(parent, collapsed)
  for _, uuid in ipairs(parent.children) do
    local child = self._node_map[uuid] ---@type eve.ux.view.treeview.INode
    child.collapsed = collapsed
    child.text = nil
    child.highlights = nil

    if child.type == "container" then
      self:update_collapse_recursively(child, collapsed)
    end
  end
end

return M
