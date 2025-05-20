---@diagnostic disable: invisible
local __module_name__ = "eve.ux.view.filetree" ---@type string

---@alias eve.ux.view.filetree.INodeData
---| eve.ux.view.filetree.IDirectoryNodeData
---| eve.ux.view.filetree.IFileNodeData
---| eve.ux.view.filetree.IPositionNodeData

---@alias eve.ux.view.filetree.INode
---| eve.ux.view.filetree.IDirectoryNode
---| eve.ux.view.filetree.IFileNode
---| eve.ux.view.filetree.IPositionNode

---@alias eve.ux.view.filetree.IDirectoryNodeRenderer
---| fun(self: eve.ux.view.Filetree, node: eve.ux.view.filetree.IDirectoryNode, root: eve.ux.view.filetree.IDirectoryNode, lnum: integer, depth: integer, folded_depth: integer): eve.ux.view.treeview.INodeRenderResult

---@alias eve.ux.view.filetree.IFileNodeRenderer
---| fun(self: eve.ux.view.Filetree, node: eve.ux.view.filetree.IFileNode, root: eve.ux.view.filetree.IDirectoryNode, lnum: integer, depth: integer): eve.ux.view.treeview.INodeRenderResult

---@alias eve.ux.view.filetree.IPositionNodeRenderer
---| fun(self: eve.ux.view.Filetree, node: eve.ux.view.filetree.IPositionNode, root: eve.ux.view.filetree.IDirectoryNode, lnum: integer, depth: integer): eve.ux.view.treeview.INodeRenderResult

---@alias eve.ux.view.filetree.IFileNodeFlattenRenderer
---| fun(self: eve.ux.view.Filetree, node: eve.ux.view.filetree.IFileNode, root: eve.ux.view.filetree.IDirectoryNode, lnum: integer): eve.ux.view.treeview.INodeRenderResult

---@alias eve.ux.view.filetree.IPositionNodeFlattenRenderer
---| fun(self: eve.ux.view.Filetree, node: eve.ux.view.filetree.IPositionNode, root: eve.ux.view.filetree.IDirectoryNode, lnum: integer): eve.ux.view.treeview.INodeRenderResult

---@class eve.ux.view.filetree.IDirectoryNodeData
---@field public basename               string
---@field public filepath               string
---@field public filepath_lower         string
---@field public icon                   string
---@field public icon_hln               string

---@class eve.ux.view.filetree.IFileNodeData
---@field public basename               string
---@field public filepath               string
---@field public filepath_lower         string
---@field public icon                   string
---@field public icon_hln               string

---@class eve.ux.view.filetree.IPositionNodeData
---@field public filepath               string
---@field public lnum                   integer
---@field public col                    ?integer
---@field public data                   ?unknown

---@class eve.ux.view.filetree.IDirectoryNode : eve.ux.view.treeview.INode
---@field public type                   "container"
---@field public parent                 eve.ux.view.filetree.IDirectoryNode
---@field public children               eve.ux.view.filetree.INode[]
---@field public data                   eve.ux.view.filetree.IDirectoryNodeData

---@class eve.ux.view.filetree.IFileNode : eve.ux.view.treeview.INode
---@field public type                   "leaf"
---@field public parent                 eve.ux.view.filetree.IDirectoryNode
---@field public children               eve.ux.view.filetree.INode[]
---@field public data                   eve.ux.view.filetree.IFileNodeData

---@class eve.ux.view.filetree.IPositionNode : eve.ux.view.treeview.INode
---@field public type                   "position"
---@field public parent                 eve.ux.view.filetree.IFileNode
---@field public data                   eve.ux.view.filetree.IPositionNodeData

----------------------------------------------------------------------------------------------------

local FILETREE_ROOT_UUID = "4d618576933d60f4b31039b123256943" ---@type string
local filepath2uuid = { [""] = FILETREE_ROOT_UUID } ---@type table<string, string>

---@type table<eve.ux.view.treeview.NodeTypeEnum, integer>
local nodetype_priority_map = {
  container = 5,
  leaf = 3,
  position = 1,
}

----------------------------------------------------------------------------------------------------

---@class eve.ux.view.IFiletreeProps
---@field public name                   string
---@field public flag_foldempty         std.collection.IObservable
---@field public indent                 ?string
---@field public indent_hln             ?string
---
---@field public directory_node_renderer        ?eve.ux.view.filetree.IDirectoryNodeRenderer
---@field public file_node_renderer             ?eve.ux.view.filetree.IFileNodeRenderer
---@field public position_node_renderer         ?eve.ux.view.filetree.IPositionNodeRenderer
---@field public file_node_flatten_renderer     ?eve.ux.view.filetree.IFileNodeRenderer
---@field public position_node_flatten_renderer ?eve.ux.view.filetree.IPositionNodeRenderer

---@class eve.ux.view.Filetree
---@field public name                   string
---@field protected _disposed           boolean
---@field protected _flag_foldempty     std.collection.IObservable
---@field protected _treeview           eve.ux.view.Treeview
---@field protected _parents_of_position table<string, true>
local M = {}
M.__index = M

---@param props                         eve.ux.view.IFiletreeProps
---@return eve.ux.view.Filetree
function M.new(props)
  local name = props.name ---@type string
  local flag_foldempty = props.flag_foldempty ---@type std.collection.IObservable
  local indent = props.indent ---@type string|nil
  local indent_hln = props.indent_hln ---@type string|nil

  local render_directory_node = props.directory_node_renderer or M.default_directory_node_renderer ---@type eve.ux.view.filetree.IDirectoryNodeRenderer
  local render_file_node = props.file_node_renderer or M.default_file_node_renderer ---@type eve.ux.view.filetree.IFileNodeRenderer
  local render_position_node = props.position_node_renderer or M.default_position_node_renderer ---@type eve.ux.view.filetree.IPositionNodeRenderer
  local flatten_render_file_node = props.file_node_flatten_renderer or M.default_file_node_flatten_renderer ---@type eve.ux.view.filetree.IFileNodeFlattenRenderer
  local flatten_render_position_node = props.position_node_flatten_renderer or M.default_position_node_flatten_renderer ---@type eve.ux.view.filetree.IPositionNodeFlattenRenderer

  local self = setmetatable({}, M)

  local treeview = eve.ux.view.Treeview.new({
    name = name,
    foldempty = flag_foldempty:snapshot(),
    indent = indent,
    indent_hln = indent_hln,
    ---@type eve.ux.view.treeview.INodeRenderer
    node_renderer = function(_, node, root, lnum, depth, folded_depth)
      ---@cast root                     eve.ux.view.filetree.IDirectoryNode

      if node.type == "container" then
        ---@cast node                     eve.ux.view.filetree.IDirectoryNode
        return render_directory_node(self, node, root, lnum, depth, folded_depth)
      end

      if node.type == "leaf" then
        ---@cast node                     eve.ux.view.filetree.IFileNode
        return render_file_node(self, node, root, lnum, depth)
      end

      if node.type == "position" then
        ---@cast node                     eve.ux.view.filetree.IPositionNode
        return render_position_node(self, node, root, lnum, depth)
      end

      error(string.format("[%s | %s] #node_renderer - Unexpected nodetype: %s", name, __module_name__, node.type))
    end,
    ---@type eve.ux.view.treeview.INodeFlattenRenderer
    node_flatten_renderer = function(_, node, root, lnum)
      ---@cast root                     eve.ux.view.filetree.IDirectoryNode

      if node.type == "leaf" then
        ---@cast node                     eve.ux.view.filetree.IFileNode
        return flatten_render_file_node(self, node, root, lnum)
      end

      if node.type == "position" then
        ---@cast node                     eve.ux.view.filetree.IPositionNode
        return flatten_render_position_node(self, node, root, lnum)
      end

      error(
        string.format("[%s | %s] #node_flatten_renderer - Unexpected nodetype: %s", name, __module_name__, node.type)
      )
    end,
    ---@type eve.ux.view.treeview.INodeSorter
    node_sorter = function(left, right)
      if left.type ~= right.type then
        local left_priority = nodetype_priority_map[left.type] ---@type integer
        local right_priority = nodetype_priority_map[right.type] ---@type integer
        return left_priority > right_priority
      end

      if left.type == "container" then
        ---@cast left                       eve.ux.view.filetree.IDirectoryNode
        ---@cast right                      eve.ux.view.filetree.IDirectoryNode
        return left.data.basename < right.data.basename
      end

      if left.type == "leaf" then
        ---@cast left                       eve.ux.view.filetree.IFileNode
        ---@cast right                      eve.ux.view.filetree.IFileNode
        return left.data.basename < right.data.basename
      end

      ---@cast left                       eve.ux.view.filetree.IPositionNode
      ---@cast right                      eve.ux.view.filetree.IPositionNode
      if left.data.lnum ~= right.data.lnum then
        return left.data.lnum < right.data.lnum
      end

      local left_col = left.data.col or 0 ---@type integer
      local right_col = right.data.col or 0 ---@type integer
      return left_col < right_col
    end,
  })

  self.name = name
  self._disposed = false
  self._flag_foldempty = flag_foldempty
  self._treeview = treeview
  self._parents_of_position = {}

  flag_foldempty:subscribe(std.Subscriber.new({
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
  self._parents_of_position = nil
end

---@return boolean
function M:isdisposed()
  return self._disposed
end

----------------------------------------------------------------------------------------------------

---@param included_uuids                string[]
---@return table<string, boolean>
function M:calc_include_uuid_set(included_uuids)
  self:__health__()
  return self._treeview:calc_include_uuid_set(included_uuids)
end

---@param uuid                          string
---@param value                         eve.ux.view.treeview.CollapseActionEnum
---@param recursive                     ?boolean
---@return eve.ux.view.Filetree
function M:collapse(uuid, value, recursive)
  self:__health__()
  self._treeview:collapse(uuid, value, recursive)
  return self
end

---@param root_uuid                     string|nil
---@return string[]
function M:collect_file_uuids(root_uuid)
  self:__health__()
  return self._treeview:collect_leaf_uuids(root_uuid)
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
---@param included_collapsed_nodes      boolean|nil
---@return eve.ux.view.treeview.IRenderResult
function M:render(bufnr, viewtype, root_uuid, included_uuid_set, included_collapsed_nodes)
  self:__health__()
  return self._treeview:render(bufnr, viewtype, root_uuid, included_uuid_set, included_collapsed_nodes)
end

---@param uuid                          string
---@param silent                        boolean|nil
---@return eve.ux.view.filetree.INode|nil
function M:retrieve_by_uuid(uuid, silent)
  self:__health__()
  local node = self._treeview:retrieve_by_uuid(uuid, silent)
  ---@cast node                         eve.ux.view.filetree.INode|nil
  return node
end

---@param filepath                     string
---@return string|nil
function M:retrieve_uuid_by_filepath(filepath)
  if std.path.is_absolute(filepath) then
    filepath = std.path.normalize(filepath) ---@type string
    return filepath2uuid[filepath]
  end
  return nil
end

----------------------------------------------------------------------------------------------------

---@return eve.ux.view.Filetree
function M:clear_positions()
  self:__health__()
  local parents_of_position = self._parents_of_position ---@type table<string, true>
  self._parents_of_position = {} ---@type table<string, true>
  for fileuuid in pairs(parents_of_position) do
    self._treeview:empty(fileuuid)
  end
  return self
end

---@param fileuuid                     string
---@param lnum                          integer
---@param col                           integer|nil
---@param data                          unknown|nil
---@return eve.ux.view.Filetree
function M:insert_position(fileuuid, lnum, col, data)
  self:__health__()
  local treeview = self._treeview ---@type eve.ux.view.Treeview
  local filenode = treeview:retrieve_by_uuid(fileuuid)
  if filenode == nil or filenode.type ~= "leaf" then
    std.reporter.error({
      from = __module_name__,
      subject = "insert_position",
      message = "Invalid fileuuid",
      details = { fileuuid = fileuuid, lnum = lnum, col = col, data = data },
    })
    return self
  end

  ---@cast filenode                     eve.ux.view.filetree.IFileNode

  local uuid = string.format("%s:%d:%d", fileuuid, lnum, col or 0) ---@type string

  ---@type eve.ux.view.filetree.IPositionNodeData
  local nodedata = {
    filepath = filenode.data.filepath,
    lnum = lnum,
    col = col,
    data = data,
  }
  treeview:insert(uuid, fileuuid, "position", nodedata, false)
  self._parents_of_position[fileuuid] = true
  return self
end

---@param cwd                           string
---@param filepaths                     string[]
---@param with_positions                boolean
---@return eve.ux.view.Filetree
function M:reset_filepaths(cwd, filepaths, with_positions)
  self:__health__()
  self._treeview:clear()
  self._parents_of_position = {} ---@type string[]

  if #filepaths < 1 then
    return self
  end

  local uuid_root = FILETREE_ROOT_UUID
  local treeview = self._treeview ---@type eve.ux.view.Treeview

  ---@type eve.ux.view.filetree.IDirectoryNodeData
  local root = {
    basename = "",
    filepath = "",
    filepath_lower = "",
    icon = eve.icon.filetype.FileTree,
    icon_hln = "MiniIconsBlue",
  }
  treeview:insert(uuid_root, uuid_root, "container", root, false)

  cwd = std.path.normalize(cwd) ---@type string
  local cwd_with_slash = cwd == "/" and "/" or cwd .. std.env.PATH_SEP ---@type string
  local cwd_length = #cwd_with_slash ---@type integer
  if cwd == "/" then
    local uuid = self:__resolve_uuid__("/") ---@type string
    ---@type eve.ux.view.filetree.IDirectoryNodeData
    local nodedata = {
      basename = cwd,
      filepath = cwd,
      filepath_lower = cwd,
      icon = eve.icon.filetype.Folder,
      icon_hln = "MiniIconsBlue",
    }
    treeview:insert(uuid, uuid_root, "container", nodedata, false)
  else
    local pieces = std.path.split(cwd) ---@type string[]
    local N = #pieces ---@type integer

    local filepath = root.filepath ---@type string
    local uuid_parent = uuid_root ---@type string
    local start_index = std.env.IS_WIN and 1 or 2 ---@type integer
    for index = start_index, N, 1 do
      local basename = pieces[index] ---@type string
      filepath = index == 1 and basename or (filepath .. std.env.PATH_SEP .. basename) ---@type string
      local uuid = self:__resolve_uuid__(filepath) ---@type string
      local icon, icon_hln = eve.fn.diricon(basename)

      ---@type eve.ux.view.filetree.IDirectoryNodeData
      local nodedata = {
        basename = basename,
        filepath = filepath,
        filepath_lower = filepath:lower(),
        icon = icon,
        icon_hln = icon_hln,
      }
      treeview:insert(uuid, uuid_parent, "container", nodedata, false)
      uuid_parent = uuid
    end
  end

  ---@param p                           string
  ---@return string
  ---@return string
  local function insert_absolute_filepath(p)
    local pieces = std.path.split(p) ---@type string[]
    local N = #pieces - 1 ---@type integer

    local filepath = root.filepath ---@type string
    local uuid_parent = uuid_root ---@type string
    local start_index = std.env.IS_WIN and 1 or 2 ---@type integer
    for index = start_index, N, 1 do
      local basename = pieces[index] ---@type string
      filepath = filepath .. std.env.PATH_SEP .. basename ---@type string
      local uuid = self:__resolve_uuid__(filepath) ---@type string
      local icon, icon_hln = eve.fn.diricon(basename)

      ---@type eve.ux.view.filetree.IDirectoryNodeData
      local nodedata = {
        basename = basename,
        filepath = filepath,
        filepath_lower = filepath:lower(),
        icon = icon,
        icon_hln = icon_hln,
      }
      treeview:insert(uuid, uuid_parent, "container", nodedata, false)
      uuid_parent = uuid ---@type string
    end

    local basename = pieces[#pieces] ---@type string
    filepath = filepath .. std.env.PATH_SEP .. basename ---@type string
    local uuid = self:__resolve_uuid__(filepath) ---@type string
    local icon, icon_hln = eve.fn.fileicon(basename)

    ---@type eve.ux.view.filetree.IFileNodeData
    local nodedata = {
      basename = basename,
      filepath = filepath,
      filepath_lower = filepath:lower(),
      icon = icon,
      icon_hln = icon_hln,
    }
    treeview:insert(uuid, uuid_parent, "leaf", nodedata, false)
    return uuid, filepath
  end

  ---@param p                           string
  ---@return string
  ---@return string
  local function insert_relative_filepath(p)
    local pieces = std.path.split(p) ---@type string[]
    local N = #pieces - 1 ---@type integer

    local filepath = cwd ---@type string
    local uuid_parent = self:__resolve_uuid__(filepath) ---@type string
    for index = 1, N, 1 do
      local basename = pieces[index] ---@type string
      filepath = filepath .. std.env.PATH_SEP .. basename ---@type string
      local uuid = self:__resolve_uuid__(filepath) ---@type string
      local icon, icon_hln = eve.fn.diricon(basename)

      ---@type eve.ux.view.filetree.IDirectoryNodeData
      local nodedata = {
        basename = basename,
        filepath = filepath,
        filepath_lower = filepath:lower(),
        icon = icon,
        icon_hln = icon_hln,
      }
      treeview:insert(uuid, uuid_parent, "container", nodedata, false)
      uuid_parent = uuid ---@type string
    end

    local basename = pieces[#pieces] ---@type string
    filepath = filepath .. std.env.PATH_SEP .. basename ---@type string
    local uuid = self:__resolve_uuid__(filepath) ---@type string
    local icon, icon_hln = eve.fn.fileicon(basename)

    ---@type eve.ux.view.filetree.IFileNodeData
    local nodedata = {
      basename = basename,
      filepath = filepath,
      filepath_lower = filepath:lower(),
      icon = icon,
      icon_hln = icon_hln,
    }
    treeview:insert(uuid, uuid_parent, "leaf", nodedata, false)
    return uuid, filepath
  end

  if with_positions then
    for _, p in ipairs(filepaths) do
      local filepath, lnum, col = std.string.parse_filepath_with_position(p) ---@type string, integer|nil, integer|nil
      local fileuuid, absolute_filepath ---@type string, string
      if std.path.is_absolute(filepath) then
        if filepath:sub(1, cwd_length) ~= cwd_with_slash then
          fileuuid, absolute_filepath = insert_absolute_filepath(filepath)
        else
          filepath = filepath:sub(cwd_length + 1) ---@type string
          fileuuid, absolute_filepath = insert_relative_filepath(filepath)
        end
      else
        fileuuid, absolute_filepath = insert_relative_filepath(filepath)
      end

      if lnum ~= nil then
        local uuid = string.format("%s:%d:%d", fileuuid, lnum, col or 0) ---@type string
        ---@type eve.ux.view.filetree.IPositionNodeData
        local nodedata = {
          filepath = absolute_filepath,
          lnum = lnum,
          col = col,
        }
        treeview:insert(uuid, fileuuid, "position", nodedata, false)
        self._parents_of_position[fileuuid] = true
      end
    end
  else
    for _, filepath in ipairs(filepaths) do
      if std.path.is_absolute(filepath) then
        if filepath:sub(1, cwd_length) ~= cwd_with_slash then
          insert_absolute_filepath(filepath)
        else
          filepath = filepath:sub(cwd_length + 1) ---@type string
          insert_relative_filepath(filepath)
        end
      else
        insert_relative_filepath(filepath)
      end
    end
  end

  return self
end

----------------------------------------------------------------------------------------------------

---@type eve.ux.view.filetree.IDirectoryNodeRenderer
function M.default_directory_node_renderer(_, node, _, _, _, folded_depth)
  local basename = node.data.basename ---@type string
  local icon = node.data.icon ---@type string
  local icon_hln = node.data.icon_hln ---@type string
  if not node.collapsed then
    if #node.children < 1 then
      icon = eve.icon.filetype.FolderEmptyOpen
    else
      icon = eve.icon.filetype.FolderOpen
    end
  end

  if folded_depth < 1 then
    local text = string.format("%s %s", icon, basename) ---@type string

    ---@type std.t.IHighlightInline[]
    local highlights = {
      { coll = 0, colr = #icon + 1, hlname = icon_hln },
      { coll = #icon + 1, colr = #text, hlname = "f_ft_dirname" },
    }
    return { text = text, highlights = highlights }
  end

  local basenames = {} ---@type string[]
  basenames[folded_depth + 1] = basename ---@type string

  local o = node ---@type eve.ux.view.filetree.IDirectoryNode
  for index = folded_depth, 1, -1 do
    basenames[index] = o.parent.data.basename ---@type string
    o = o.parent
  end

  local text = string.format("%s %s", icon, basenames[1]) ---@type string

  ---@type std.t.IHighlightInline[]
  local highlights = {
    { coll = 0, colr = #icon + 1, hlname = icon_hln },
    { coll = #icon + 1, colr = #text, hlname = "f_ft_dirname" },
  }

  for index = 2, #basenames, 1 do
    local piece = basenames[index] ---@type string
    local offset = #text ---@type integer
    text = text .. string.format("/%s", piece)
    highlights[#highlights + 1] = { coll = offset, colr = offset + 1, hlname = "f_ft_pathsep" }
    highlights[#highlights + 1] = { coll = offset + 1, colr = #text, hlname = "f_ft_dirname" }
  end

  return { text = text, highlights = highlights }
end

---@type eve.ux.view.filetree.IFileNodeRenderer
function M.default_file_node_renderer(_, node)
  local basename = node.data.basename ---@type string
  local icon = node.data.icon ---@type string
  local icon_hln = node.data.icon_hln ---@type string

  local text = string.format("%s %s", icon, basename) ---@type string

  ---@type std.t.IHighlightInline[]
  local highlights = {
    { coll = 0, colr = #icon + 1, hlname = icon_hln },
    { coll = #icon + 1, colr = #text, hlname = "f_ft_filename" },
  }
  return { text = text, highlights = highlights }
end

---@type eve.ux.view.filetree.IPositionNodeRenderer
function M.default_position_node_renderer(_, node)
  local lnum = node.data.lnum
  local col = node.data.col

  local text = col ~= nil and string.format("%4d:%-4d", lnum, col) or string.format("%4d:", lnum) ---@type string

  ---@type std.t.IHighlightInline[]
  local highlights = {
    { coll = 0, colr = #text, hlname = "f_ft_position" },
  }
  return { text = text, highlights = highlights }
end

---@type eve.ux.view.filetree.IFileNodeFlattenRenderer
function M.default_file_node_flatten_renderer(_, node, root)
  local nodedata = node.data ---@type eve.ux.view.filetree.IFileNodeData
  local icon, icon_hln = eve.fn.fileicon(nodedata.basename) ---@type string, string

  local filepath = #root.data.filepath < 2 and nodedata.filepath or nodedata.filepath:sub(#root.data.filepath + 2) ---@type string
  local text = string.format("%s %s", icon, filepath) ---@type string
  local highlights = { { coll = 0, colr = #icon + 1, hlname = icon_hln } } ---@type std.t.IHighlightInline[]

  ---@type eve.ux.view.treeview.INodeRenderResult
  local result = { text = text, highlights = highlights }
  return result
end

---@type eve.ux.view.filetree.IPositionNodeFlattenRenderer
function M.default_position_node_flatten_renderer(_, node)
  local lnum = node.data.lnum
  local col = node.data.col

  local text = col ~= nil and string.format("%4d:%-4d", lnum, col) or string.format("%4d:", lnum) ---@type string

  ---@type std.t.IHighlightInline[]
  local highlights = {
    { coll = 0, colr = #text, hlname = "f_ft_position" },
  }
  return { text = text, highlights = highlights }
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

---@param filepath                      string
---@return string
function M:__resolve_uuid__(filepath)
  local uuid = filepath2uuid[filepath] ---@type string|nil
  if uuid == nil then
    uuid = std.fn.md5(filepath) ---@type string
    filepath2uuid[filepath] = uuid
  end
  return uuid
end

return M
