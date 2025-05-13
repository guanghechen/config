local __module_name__ = "eve.ux.view.treeview" ---@type string

---@alias eve.ux.view.treeview.ViewtypeEnum
---| "tree"
---| "list"

---@alias eve.ux.view.treeview.CollapseActionEnum
---| "collapse"
---| "expand"
---| "toggle"

---@alias eve.ux.view.treeview.INodeRenderer
---| fun(treeview: eve.ux.view.Treeview, node: eve.ux.view.treeview.INode, root: eve.ux.view.treeview.INode, folded_depth: integer, depth: integer): eve.ux.view.treeview.INodeRenderResult

---@alias eve.ux.view.treeview.INodeFlattenRenderer
---| fun(treeview: eve.ux.view.Treeview, node: eve.ux.view.treeview.INode, root: eve.ux.view.treeview.INode): eve.ux.view.treeview.INodeRenderResult

---@alias eve.ux.view.treeview.INodeSorter
---| fun(left: eve.ux.view.treeview.INode, right: eve.ux.view.treeview.INode): boolean

---@alias eve.ux.view.treeview.IRenderTree
---| fun(node: eve.ux.view.treeview.INode, depth: integer, indent: string, folded_depth: integer, is_last: boolean): nil

---@alias eve.ux.view.treeview.IRenderTreeRecursive
---| fun(node: eve.ux.view.treeview.INode, depth: integer, indent: string, folded_depth: integer, is_last: boolean): nil

---@alias eve.ux.view.treeview.IRenderList
---| fun(node: eve.ux.view.treeview.INode): nil

---@alias eve.ux.view.treeview.IRenderListRecursive
---| fun(node: eve.ux.view.treeview.INode): nil

---@class eve.ux.view.treeview.INodeRenderResult
---@field public text                   string
---@field public highlights             eve.t.IHighlightInline[]|nil

---@class eve.ux.view.treeview.INodeRenderResultCache
---@field public tick                   integer
---@field public text                   string
---@field public highlights             eve.t.IHighlightInline[]

---@class eve.ux.view.treeview.INode
---@field public uuid                   string
---@field public parent                 string
---@field public data                   unknown
---@field public leaf                   boolean
---@field public collapsed              boolean
---@field public dirty_orders           boolean
---@field public children               string[]
---@field public cache_treeview         eve.ux.view.treeview.INodeRenderResultCache|nil
---@field public cache_listview         eve.ux.view.treeview.INodeRenderResultCache|nil

---@class eve.ux.view.treeview.IRenderResult
---@field public uuids                  string[]

---@class eve.ux.view.ITreeviewProps
---@field public name                   string
---@field public nsnr                   ?integer
---@field public foldempty              ?boolean
---@field public indent                 ?string
---@field public indent_hln             ?string
---@field public node_flat_renderer     eve.ux.view.treeview.INodeFlattenRenderer
---@field public node_renderer          eve.ux.view.treeview.INodeRenderer
---@field public node_sorter            eve.ux.view.treeview.INodeSorter

---@class eve.ux.view.Treeview
---@field public name                   string
---@field public nsnr                   integer
---@field protected _disposed           boolean
---@field protected _foldempty          boolean
---@field protected _tick_listview      integer
---@field protected _tick_treeview      integer
---
---@field protected _indent             string
---@field protected _indent_hln         string
---@field protected _node_map           table<string, eve.ux.view.treeview.INode>
---@field protected _node_root          eve.ux.view.treeview.INode
---@field protected _node_flat_renderer eve.ux.view.treeview.INodeFlattenRenderer
---@field protected _node_renderer      eve.ux.view.treeview.INodeRenderer
---@field protected _node_sorter        eve.ux.view.treeview.INodeSorter
local M = {}
M.__index = M

local NSNR_DEFAULT = eve.var.nsnr.view_treeview ---@type integer

---@param props                         eve.ux.view.ITreeviewProps
---@return eve.ux.view.Treeview
function M.new(props)
  local name = props.name ---@type string
  local nsnr = props.nsnr or NSNR_DEFAULT ---@type integer
  local foldempty = props.foldempty ~= false ---@type boolean
  local indent = props.indent or "" ---@type string
  local indent_hln = props.indent_hln or "f_utw_indent" ---@type string
  local node_flat_renderer = props.node_flat_renderer ---@type eve.ux.view.treeview.INodeFlattenRenderer
  local node_renderer = props.node_renderer ---@type eve.ux.view.treeview.INodeRenderer
  local sorter = props.node_sorter ---@type eve.ux.view.treeview.INodeSorter

  local self = setmetatable({}, M)

  ---@type eve.ux.view.treeview.INode
  local root = {
    parent = "__virtual_root__",
    uuid = "__virtual_root__",
    data = nil,
    leaf = false,
    collapsed = false,
    dirty_orders = false,
    children = {},
  }

  self.name = name
  self.nsnr = nsnr
  self._disposed = false
  self._foldempty = foldempty
  self._tick_listview = 0
  self._tick_treeview = 0
  self._indent = indent
  self._indent_hln = indent_hln
  self._node_map = { [root.uuid] = root }
  self._node_root = root
  self._node_flat_renderer = node_flat_renderer
  self._node_renderer = node_renderer
  self._node_sorter = sorter
  return self
end

---@return eve.ux.view.Treeview
function M:clear()
  self:__health__()

  local root = self._node_root ---@type eve.ux.view.treeview.INode
  self._tick_listview = self._tick_listview + 1
  self._tick_treeview = self._tick_treeview + 1
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

  self._foldempty = nil
  self._tick_listview = nil
  self._tick_treeview = nil

  self._indent = nil
  self._indent_hln = nil
  self._node_map = nil
  self._node_root = nil
  self._node_flat_renderer = nil
  self._node_renderer = nil
  self._node_sorter = nil
end

---@return boolean
function M:isdisposed()
  return self._disposed
end

---@return boolean
function M:isfoldempty()
  return self._foldempty
end

---@param bufnr                         integer
---@param viewtype                      eve.ux.view.treeview.ViewtypeEnum
---@param root_uuid                     string|nil
---@param included_uuid_set             table<string, boolean>|nil
---@return eve.ux.view.treeview.IRenderResult
function M:render(bufnr, viewtype, root_uuid, included_uuid_set)
  self:__health__()

  if viewtype == "list" then
    return self:__render_list__(bufnr, root_uuid, included_uuid_set)
  end

  if viewtype == "tree" then
    return self:__render_tree__(bufnr, root_uuid, included_uuid_set)
  end

  local message = string.format("[%s#%s] The viewtype (%s) is not supported.", __module_name__, self.name, viewtype) ---@type string
  error(message)
end

----------------------------------------------------------------------------------------------------

---@param uuid                          string
---@param value                         eve.ux.view.treeview.CollapseActionEnum
---@param recursive                     ?boolean
---@return eve.ux.view.Treeview
function M:collapse(uuid, value, recursive)
  self:__health__()

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

  local collapsed = node.collapsed ---@type boolean
  if value == "toggle" then
    collapsed = not collapsed
  elseif value == "collapse" then
    collapsed = true
  elseif value == "expand" then
    collapsed = false
  end

  node.collapsed = collapsed
  node.cache_treeview = nil
  if recursive then
    self:__update_collapse_recursively__(node, collapsed)
  end
  return self
end

---@param uuid                          string
---@param parent_uuid                   string
---@param data                          unknown
---@param leaf                          boolean
---@param collapsed                     boolean
---@return eve.ux.view.Treeview
function M:insert(uuid, parent_uuid, data, leaf, collapsed)
  self:__health__()

  local node_map = self._node_map ---@type table<string, eve.ux.view.treeview.INode>
  local node = node_map[uuid] ---@type eve.ux.view.treeview.INode|nil
  if node ~= nil then
    return self:update(uuid, parent_uuid, data, leaf, collapsed)
  end

  local parent = self:__retrieve_parent__(uuid, parent_uuid) ---@type eve.ux.view.treeview.INode|nil
  if parent == nil then
    return self
  end

  ---@type eve.ux.view.treeview.INode
  local new_node = {
    uuid = uuid,
    parent = parent_uuid,
    leaf = leaf,
    collapsed = collapsed,
    data = data,
    dirty_orders = false,
    children = {},
  }

  parent.children[#parent.children + 1] = uuid
  parent.dirty_orders = true
  node_map[uuid] = new_node
  return self
end

---@param uuid                          string
---@return eve.ux.view.Treeview
function M:remove(uuid)
  self:__health__()

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

  local parent = self:__retrieve_parent__(uuid, node.parent) ---@type eve.ux.view.treeview.INode|nil
  if parent == nil then
    return self
  end

  local children = parent.children ---@type string[]
  local k, N = 1, #children ---@type integer, integer
  for index = 1, N, 1 do
    local child_uuid = children[index] ---@type string
    if child_uuid ~= uuid then
      children[k] = child_uuid
      k = k + 1
    end
  end
  for index = N, k, -1 do
    children[index] = nil
  end

  self:__remove_recursively__(node)
  return self
end

---@param uuid                          string
---@param parent_uuid                   string|nil
---@param data                          unknown
---@param leaf                          boolean
---@param collapsed                     ?boolean
---@param insert_if_non_exist           ?boolean
---@return eve.ux.view.Treeview
function M:update(uuid, parent_uuid, data, leaf, collapsed, insert_if_non_exist)
  self:__health__()

  local node_map = self._node_map ---@type table<string, eve.ux.view.treeview.INode>
  local node = node_map[uuid] ---@type eve.ux.view.treeview.INode|nil
  if node == nil then
    if not insert_if_non_exist then
      eve.reporter.error({
        from = __module_name__,
        subject = "update (ignored)",
        message = "The node isn't exist",
        details = { uuid = uuid, parent_uuid = parent_uuid, data = data, collapsed = collapsed },
      })
      return self
    end

    if parent_uuid == nil then
      eve.reporter.error({
        from = __module_name__,
        subject = "update (ignored)",
        message = "The node isn't exist and the parent_uuid not provided",
        details = { uuid = uuid, parent_uuid = parent_uuid, data = data, collapsed = collapsed },
      })
      return self
    end

    return self:insert(uuid, parent_uuid, data, leaf, collapsed == true)
  end

  node.cache_treeview = nil
  node.cache_listview = nil

  parent_uuid = parent_uuid or node.parent ---@type string
  if node.parent == parent_uuid then
    node.data = data
    if collapsed ~= nil then
      node.collapsed = collapsed ---@type boolean
    end
    return self
  end

  local old_parent = self:__retrieve_parent__(uuid, node.parent) ---@type eve.ux.view.treeview.INode|nil
  if old_parent == nil then
    return self
  end

  local parent = self:__retrieve_parent__(uuid, parent_uuid) ---@type eve.ux.view.treeview.INode|nil
  if parent == nil then
    return self
  end

  local children = old_parent.children ---@type string[]
  local k, N = 1, #children ---@type integer, integer
  for index = 1, N, 1 do
    local child_uuid = children[index] ---@type string
    if child_uuid ~= uuid then
      children[k] = child_uuid
      k = k + 1
    end
  end
  for index = N, k, -1 do
    children[index] = nil
  end

  if collapsed ~= nil then
    node.collapsed = collapsed ---@type boolean
  end
  node.data = data
  node.parent = parent_uuid
  parent.children[#parent.children + 1] = uuid
  parent.dirty_orders = true
  return self
end

----------------------------------------------------------------------------------------------------

---@param included_uuids                string[]
---@return table<string, boolean>
function M:calc_include_uuid_set(included_uuids)
  self:__health__()

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

---@param root_uuid                     string|nil
---@return string[]
function M:collect_leaf_uuids(root_uuid)
  self:__health__()
  local root = (root_uuid ~= nil and self._node_map[root_uuid]) or self._node_root
  local uuids = {} ---@type string[]

  ---@param node                        eve.ux.view.treeview.INode
  ---@return nil
  local function recursive(node)
    if node.leaf then
      uuids[#uuids + 1] = node.uuid
    end

    if node.dirty_orders then
      self:__sort_children__(node)
    end

    for _, uuid in ipairs(node.children) do
      local child = self._node_map[uuid] ---@type eve.ux.view.treeview.INode
      recursive(child)
    end
  end

  recursive(root)
  return uuids
end

---@param uuid                          string
---@return boolean
function M:has(uuid)
  self:__health__()
  return self._node_map[uuid] ~= nil
end

---@return eve.ux.view.Treeview
function M:mark_listview_node_cache_dirty()
  self:__health__()
  self._tick_listview = self._tick_listview + 1
  return self
end

---@return eve.ux.view.Treeview
function M:mark_treeview_node_cache_dirty()
  self:__health__()
  self._tick_treeview = self._tick_treeview + 1
  return self
end

---@param uuid                          string
---@param silent                        boolean|nil
---@return eve.ux.view.treeview.INode|nil
function M:retrieve_by_uuid(uuid, silent)
  self:__health__()

  local node = self._node_map[uuid] ---@type eve.ux.view.treeview.INode|nil
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

---@param foldempty                     boolean
---@return eve.ux.view.Treeview
function M:set_foldempty(foldempty)
  self:__health__()
  if self._foldempty ~= foldempty then
    self._foldempty = foldempty
    self._tick_treeview = self._tick_treeview + 1
  end
  return self
end

----------------------------------------------------------------------------------------------------

---@protected
---@return nil
function M:__health__()
  if self._disposed then
    local message = string.format("Treeview (%s) has been disposed.", self.name) ---@type string
    error(message)
  end
end

---@protected
---@param node                          eve.ux.view.treeview.INode
---@return nil
function M:__remove_recursively__(node)
  local node_map = self._node_map ---@type table<string, eve.ux.view.treeview.INode>
  node_map[node.uuid] = nil
  for _, uuid in ipairs(node.children) do
    local child = node_map[uuid] ---@type eve.ux.view.treeview.INode
    self:__remove_recursively__(child)
  end
end

---@param bufnr                         integer
---@param root_uuid                     string|nil
---@param included_uuid_set             table<string, boolean>|nil
---@return eve.ux.view.treeview.IRenderResult
function M:__render_list__(bufnr, root_uuid, included_uuid_set)
  local uuids = {} ---@type string[]
  local tick_listview = self._tick_listview ---@type integer

  local root = (root_uuid ~= nil and self._node_map[root_uuid]) or self._node_root
  local nsnr = self.nsnr ---@type integer

  if included_uuid_set ~= nil and not included_uuid_set[root.uuid] then
    vim.api.nvim_buf_clear_namespace(bufnr, nsnr, 0, -1)
    vim.api.nvim_buf_set_lines(bufnr, 0, -1, false, {})

    ---@type eve.ux.view.treeview.IRenderResult
    local result = {
      uuids = uuids,
    }
    return result
  end

  local node_map = self._node_map ---@type table<string, eve.ux.view.treeview.INode>
  local indent = self._indent ---@type string

  local row = 0 ---@type integer
  local render ---@type eve.ux.view.treeview.IRenderList
  local recursive ---@type eve.ux.view.treeview.IRenderListRecursive

  ---@type eve.ux.view.treeview.IRenderList
  render = function(node)
    local cache = node.cache_listview ---@type eve.ux.view.treeview.INodeRenderResultCache|nil
    if cache == nil or cache.tick ~= tick_listview then
      local result = self._node_flat_renderer(self, node, root) ---@type eve.ux.view.treeview.INodeRenderResult
      ---@type eve.ux.view.treeview.INodeRenderResultCache
      cache = {
        tick = tick_listview,
        text = result.text,
        highlights = result.highlights or {},
      }
      node.cache_listview = cache
    end

    local lnum = row + 1 ---@type integer
    local text = indent .. cache.text ---@type string
    vim.api.nvim_buf_set_lines(bufnr, row, lnum, false, { text })

    local offset = #indent ---@type integer
    vim.hl.range(bufnr, nsnr, self._indent_hln, { row, 0 }, { row, offset })
    for _, highlight in ipairs(cache.highlights) do
      local hlname = highlight.hlname ---@type string
      local colr = highlight.colr ---@type integer
      local coll = highlight.coll ---@type integer
      vim.hl.range(bufnr, nsnr, hlname, { row, offset + coll }, { row, offset + colr })
    end

    uuids[#uuids + 1] = node.uuid
    row = row + 1 ---@type integer
  end

  if included_uuid_set == nil then
    ---@type eve.ux.view.treeview.IRenderListRecursive
    recursive = function(node)
      if node.leaf then
        render(node)
        return
      end

      local N = #node.children ---@type integer
      for index = 1, N, 1 do
        local child_uuid = node.children[index] ---@type string
        local child = node_map[child_uuid] ---@type eve.ux.view.treeview.INode
        recursive(child)
      end
    end
  else
    ---@type eve.ux.view.treeview.IRenderListRecursive
    recursive = function(node)
      if node.leaf and included_uuid_set[node.uuid] then
        render(node)
        return
      end

      local N = #node.children ---@type integer
      for index = 1, N, 1 do
        local child_uuid = node.children[index] ---@type string
        local child = node_map[child_uuid] ---@type eve.ux.view.treeview.INode
        recursive(child)
      end
    end
  end

  vim.api.nvim_buf_clear_namespace(bufnr, nsnr, 0, -1)
  recursive(root)
  vim.api.nvim_buf_set_lines(bufnr, row, -1, false, {})

  ---@type eve.ux.view.treeview.IRenderResult
  local result = { uuids = uuids }
  return result
end

---@param bufnr                         integer
---@param root_uuid                     string|nil
---@param included_uuid_set             table<string, boolean>|nil
---@return eve.ux.view.treeview.IRenderResult
function M:__render_tree__(bufnr, root_uuid, included_uuid_set)
  local uuids = {} ---@type string[]
  local foldempty = self._foldempty ---@type boolean
  local tick_treeview = self._tick_treeview ---@type integer

  local root = (root_uuid ~= nil and self._node_map[root_uuid]) or self._node_root
  local nsnr = self.nsnr ---@type integer

  if included_uuid_set ~= nil and not included_uuid_set[root.uuid] then
    vim.api.nvim_buf_clear_namespace(bufnr, nsnr, 0, -1)
    vim.api.nvim_buf_set_lines(bufnr, 0, -1, false, {})

    ---@type eve.ux.view.treeview.IRenderResult
    local result = {
      uuids = uuids,
    }
    return result
  end

  local node_map = self._node_map ---@type table<string, eve.ux.view.treeview.INode>

  local row = 0 ---@type integer
  local render ---@type eve.ux.view.treeview.IRenderTree
  local recursive ---@type eve.ux.view.treeview.IRenderTreeRecursive

  ---@type eve.ux.view.treeview.IRenderTree
  render = function(node, depth, indent, folded_depth, is_last)
    local cache = node.cache_treeview ---@type eve.ux.view.treeview.INodeRenderResultCache|nil
    if cache == nil or cache.tick ~= tick_treeview then
      local result = self._node_renderer(self, node, root, folded_depth, depth) ---@type eve.ux.view.treeview.INodeRenderResult
      ---@type eve.ux.view.treeview.INodeRenderResultCache
      cache = {
        tick = tick_treeview,
        text = result.text,
        highlights = result.highlights or {},
      }
      node.cache_treeview = cache
    end

    if depth > 0 then
      indent = indent .. (is_last and "╰─" or "├─") ---@type string
    end

    local lnum = row + 1 ---@type integer
    local text = indent .. cache.text ---@type string
    vim.api.nvim_buf_set_lines(bufnr, row, lnum, false, { text })

    local offset = #indent ---@type integer
    vim.hl.range(bufnr, nsnr, self._indent_hln, { row, 0 }, { row, offset })
    for _, highlight in ipairs(cache.highlights) do
      local hlname = highlight.hlname ---@type string
      local colr = highlight.colr ---@type integer
      local coll = highlight.coll ---@type integer
      vim.hl.range(bufnr, nsnr, hlname, { row, offset + coll }, { row, offset + colr })
    end

    uuids[#uuids + 1] = node.uuid
    row = row + 1 ---@type integer
  end

  if included_uuid_set == nil then
    ---@type eve.ux.view.treeview.IRenderTreeRecursive
    recursive = function(node, depth, indent, folded_depth, is_last)
      if node.collapsed or #node.children < 1 then
        render(node, depth, indent, folded_depth, is_last)
        return
      end

      local N = #node.children ---@type integer
      if N == 1 and foldempty then
        local child_uuid = node.children[1] ---@type string
        local child = node_map[child_uuid] ---@type eve.ux.view.treeview.INode
        if not child.leaf then
          return recursive(child, depth, indent, folded_depth + 1, is_last)
        end
      end

      render(node, depth, indent, folded_depth, is_last)

      if node.dirty_orders then
        self:__sort_children__(node)
      end

      local child_depth = depth + 1 ---@type integer
      local child_indent = depth == 0 and indent or (indent .. (is_last and "  " or "│ ")) ---@type string
      for index = 1, N, 1 do
        local child_uuid = node.children[index] ---@type string
        local child = node_map[child_uuid] ---@type eve.ux.view.treeview.INode
        recursive(child, child_depth, child_indent, 0, index == N)
      end
    end
  else
    ---@type eve.ux.view.treeview.IRenderTreeRecursive
    recursive = function(node, depth, indent, folded_depth, is_last)
      if node.collapsed or #node.children < 1 then
        render(node, depth, indent, folded_depth, is_last)
        return
      end

      if node.dirty_orders then
        self:__sort_children__(node)
      end

      local first_child_index = nil ---@type integer|nil
      local last_child_index = #node.children ---@type integer
      for index, child_uuid in ipairs(node.children) do
        if included_uuid_set[child_uuid] then
          first_child_index = first_child_index or index ---@type integer
          last_child_index = index ---@type integer
        end
      end

      if first_child_index == last_child_index and foldempty then
        local child_uuid = node.children[first_child_index] ---@type string
        local child = node_map[child_uuid] ---@type eve.ux.view.treeview.INode
        if not child.leaf then
          return recursive(child, depth, indent, folded_depth + 1, is_last)
        end
      end

      render(node, depth, indent, folded_depth, is_last)

      if first_child_index ~= nil then
        local child_depth = depth + 1 ---@type integer
        local child_indent = depth == 0 and indent or (indent .. (is_last and "  " or "│ ")) ---@type string
        for index = first_child_index, last_child_index, 1 do
          local child_uuid = node.children[index] ---@type string
          if included_uuid_set[child_uuid] then
            local child = node_map[child_uuid] ---@type eve.ux.view.treeview.INode
            recursive(child, child_depth, child_indent, 0, index == last_child_index)
          end
        end
      end
    end
  end

  vim.api.nvim_buf_clear_namespace(bufnr, nsnr, 0, -1)
  recursive(root, 0, self._indent, 0, true)
  vim.api.nvim_buf_set_lines(bufnr, row, -1, false, {})

  ---@type eve.ux.view.treeview.IRenderResult
  local result = { uuids = uuids }
  return result
end

---@protected
---@param uuid                          string
---@param parent_uuid                   string
---@return eve.ux.view.treeview.INode|nil
function M:__retrieve_parent__(uuid, parent_uuid)
  if uuid == parent_uuid then
    return self._node_root
  end

  local parent = self._node_map[parent_uuid] ---@type eve.ux.view.treeview.INode|nil
  if parent == nil then
    eve.reporter.error({
      from = __module_name__,
      subject = "retrieve_parent",
      message = "The expected parent is not exist",
      details = { uuid = uuid, parent_uuid = parent_uuid },
    })
    return nil
  end
  return parent
end

---@protected
---@param parent                        eve.ux.view.treeview.INode
---@return nil
function M:__sort_children__(parent)
  parent.dirty_orders = false
  if #parent.children > 1 then
    table.sort(parent.children, function(uuid_left, uuid_right)
      local left = self._node_map[uuid_left] ---@type eve.ux.view.treeview.INode
      local right = self._node_map[uuid_right] ---@type eve.ux.view.treeview.INode
      return self._node_sorter(left, right)
    end)
  end
end

---@protected
---@param node                          eve.ux.view.treeview.INode
---@param collapsed                     boolean
---@return nil
function M:__update_collapse_recursively__(node, collapsed)
  node.collapsed = collapsed
  node.cache_treeview = nil
  for _, uuid in ipairs(node.children) do
    local child = self._node_map[uuid] ---@type eve.ux.view.treeview.INode
    self:__update_collapse_recursively__(child, collapsed)
  end
end

return M
