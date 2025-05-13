---@diagnostic disable: invisible
local __module_name__ = "eve.ux.view.filetree" ---@type string

---@alias eve.ux.filetree.NodetypeEnum
---| "directory"
---| "file"

---@class eve.ux.view.filetree.INode : eve.ux.view.treeview.INode
---@field public data                   eve.ux.filetree.INodeData

---@class eve.ux.filetree.INodeData
---@field public uuid                   string
---@field public basename               string
---@field public filepath               string
---@field public filepath_lower         string
---@field public nodetype               eve.ux.filetree.NodetypeEnum

---@class eve.ux.view.IFiletreeProps
---@field public name                   string
---@field public flag_foldempty         eve.std.collection.IObservable
---@field public indent                 ?string
---@field public indent_hln             ?string

---@class eve.ux.view.Filetree
---@field public name                   string
---@field protected _disposed           boolean
---@field protected _flag_foldempty     eve.std.collection.IObservable
---@field protected _treeview           eve.ux.view.Treeview
local M = {}
M.__index = M

---@param props                         eve.ux.view.IFiletreeProps
---@return eve.ux.view.Filetree
function M.new(props)
  local name = props.name ---@type string
  local flag_foldempty = props.flag_foldempty ---@type eve.std.collection.IObservable
  local indent = props.indent ---@type string|nil
  local indent_hln = props.indent_hln ---@type string|nil

  local self = setmetatable({}, M)

  local treeview = eve.ux.view.Treeview.new({
    name = name,
    foldempty = flag_foldempty:snapshot(),
    indent = indent,
    indent_hln = indent_hln,
    ---@type eve.ux.view.treeview.INodeRenderer
    node_renderer = function(treeview, node, root, folded_depth, depth)
      ---@cast node                     eve.ux.view.filetree.INode
      ---@cast root                     eve.ux.view.filetree.INode
      return self:__render_node__(treeview, node, root, folded_depth, depth)
    end,
    ---@type eve.ux.view.treeview.INodeFlattenRenderer
    node_flat_renderer = function(treeview, node, root)
      ---@cast node                     eve.ux.view.filetree.INode
      ---@cast root                     eve.ux.view.filetree.INode
      return self:__render_node_flatten__(treeview, node, root)
    end,
    ---@type eve.ux.view.treeview.INodeSorter
    node_sorter = function(left, right)
      ---@cast left                     eve.ux.view.filetree.INode
      ---@cast right                    eve.ux.view.filetree.INode
      return self:__sort_node__(left, right)
    end,
  })

  self.name = name
  self._disposed = false
  self._flag_foldempty = flag_foldempty
  self._treeview = treeview

  flag_foldempty:subscribe(eve.std.Subscriber.new({
    on_next = function(value)
      treeview:set_foldempty(value)
    end,
  }))

  return self
end

---@return nil
function M:dispose()
  if self._disposed then
    return
  end
  self._disposed = true

  self._treeview:dispose()

  self._flag_foldempty = nil
  self._treeview = nil
end

---@return boolean
function M:isdisposed()
  return self._disposed
end

----------------------------------------------------------------------------------------------------

---@param uuid                          string
---@param value                         eve.ux.view.treeview.CollapseActionEnum
---@param recursive                     ?boolean
---@return eve.ux.view.Filetree
function M:collapse(uuid, value, recursive)
  self:__health__()
  self._treeview:collapse(uuid, value, recursive)
  return self
end

---@return eve.ux.view.Filetree
function M:mark_listview_node_cache_dirty()
  self:__health__()
  self._treeview:mark_listview_node_cache_dirty()
  return self
end

---@return eve.ux.view.Filetree
function M:mark_treeview_node_cache_dirty()
  self:__health__()
  self._treeview:mark_treeview_node_cache_dirty()
  return self
end

---@param bufnr                         integer
---@param viewtype                      eve.ux.view.treeview.ViewtypeEnum
---@param root_uuid                     string|nil
---@param included_uuid_set             table<string, boolean>|nil
---@return eve.ux.view.treeview.IRenderResult
function M:render(bufnr, viewtype, root_uuid, included_uuid_set)
  self:__health__()
  return self._treeview:render(bufnr, viewtype, root_uuid, included_uuid_set)
end

---@return eve.ux.view.filetree.INode|nil
function M:retrieve_by_uuid(uuid)
  self:__health__()
  local node = self._treeview:retrieve_by_uuid(uuid)
  ---@cast node                         eve.ux.view.filetree.INode|nil
  return node
end

----------------------------------------------------------------------------------------------------

---@protected
---@return nil
function M:__health__()
  if self._disposed then
    local message = string.format("[%s#%s] already been disposed.", __module_name__, self.name) ---@type string
    error(message)
  end
end

---@protected
---@param treeview                      eve.ux.view.Treeview
---@param node                          eve.ux.view.filetree.INode
---@param root                          eve.ux.view.filetree.INode
---@param folded_depth                  integer
---@param depth                         integer
---@return eve.ux.view.treeview.INodeRenderResult
function M:__render_node__(treeview, node, root, folded_depth, depth)
  local data = node.data ---@type eve.ux.filetree.INodeData
  local icon, icon_hln ---@type string, string

  if data.nodetype == "directory" then
    icon, icon_hln = eve.fn.diricon(data.basename)
    if not node.collapsed then
      if #node.children < 1 then
        icon = eve.icon.filetype.FolderEmptyOpen
      else
        icon = eve.icon.filetype.FolderOpen
      end
    end
  else
    icon, icon_hln = eve.fn.fileicon(data.basename)
  end

  local text ---@type string
  local highlights = { { coll = 0, colr = #icon + 1, hlname = icon_hln } } ---@type eve.t.IHighlightInline[]

  if folded_depth < 1 then
    text = string.format("%s %s", icon, data.basename) ---@type string
    local hln_basename = data.nodetype == "directory" and "f_ft_dirname" or "f_ft_filename" ---@type string
    highlights[#highlights + 1] = { coll = #icon + 1, colr = #text, hlname = hln_basename }
  else
    local basenames = {} ---@type string[]
    basenames[folded_depth + 1] = data.basename ---@type string

    local o = node
    for index = folded_depth, 1, -1 do
      local parent_uuid = o.parent ---@type string
      local parent = treeview:retrieve_by_uuid(parent_uuid)
      ---@cast parent eve.ux.view.filetree.INode

      local parent_data = parent.data ---@type eve.ux.filetree.INodeData
      basenames[index] = parent_data.basename ---@type string
      o = parent
    end

    text = string.format("%s %s", icon, basenames[1]) ---@type string
    highlights[#highlights + 1] = { coll = #icon + 1, colr = #text, hlname = "f_ft_dirname" }

    for index = 2, #basenames, 1 do
      local basename = basenames[index] ---@type string
      local offset = #text ---@type integer
      text = text .. string.format("/%s", basename)
      highlights[#highlights + 1] = { coll = offset, colr = offset + 1, hlname = "f_ft_pathsep" }
      highlights[#highlights + 1] = { coll = offset + 1, colr = #text, hlname = "f_ft_dirname" }
    end
  end

  return { text = text, highlights = highlights }
end

---@protected
---@param treeview                      eve.ux.view.Treeview
---@param node                          eve.ux.view.filetree.INode
---@param root                          eve.ux.view.filetree.INode
---@return eve.ux.view.treeview.INodeRenderResult
---@diagnostic disable-next-line: unused-local
function M:__render_node_flatten__(treeview, node, root)
  local data = node.data ---@type eve.ux.filetree.INodeData
  local icon, icon_hln = eve.fn.fileicon(data.basename) ---@type string, string

  local filepath = #root.data.filepath < 2 and data.filepath or data.filepath:sub(#root.data.filepath + 2) ---@type string
  local text = string.format("%s %s", icon, filepath) ---@type string
  local highlights = { { coll = 0, colr = #icon + 1, hlname = icon_hln } } ---@type eve.t.IHighlightInline[]

  ---@type eve.ux.view.treeview.INodeRenderResult
  local result = { text = text, highlights = highlights }
  return result
end

---@param left                          eve.ux.view.filetree.INode
---@param right                         eve.ux.view.filetree.INode
---@return boolean
function M:__sort_node__(left, right)
  if left.leaf ~= right.leaf then
    return right.leaf
  end
  return left.data.basename < right.data.basename
end

return M
