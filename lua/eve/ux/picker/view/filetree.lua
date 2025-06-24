---@diagnostic disable: invisible
local __module_name__ = "eve.ux.picker.view.filetree" ---@type string

---@alias eve.ux.picker.view.filetree.INodeState
---| eve.ux.picker.view.filetree.IDirectoryNodeState
---| eve.ux.picker.view.filetree.IFileNodeState
---| eve.ux.picker.view.filetree.ILocationNodeState

---@alias eve.ux.picker.view.filetree.IListviewFileRenderer
---| fun(ctx: eve.ux.picker.view.filetree.IListviewRendererContext, node: std.collection.filetree.INode, nodestate: eve.ux.picker.view.filetree.IFileNodeState, lnum: integer): eve.ux.picker.view.tree.INodeRenderResult

---@alias eve.ux.picker.view.filetree.IListviewLocationRenderer
---| fun(ctx: eve.ux.picker.view.filetree.IListviewRendererContext, node: std.collection.filetree.INode, nodestate: eve.ux.picker.view.filetree.IFileNodeState, locationstate: eve.ux.picker.view.filetree.ILocationNodeState, lnum: integer): eve.ux.picker.view.tree.INodeRenderResult

---@alias eve.ux.picker.view.filetree.ITreeviewDirectoryRenderer
---| fun(ctx: eve.ux.picker.view.filetree.ITreeviewRendererContext, node: std.collection.filetree.INode, nodestate: eve.ux.picker.view.filetree.IDirectoryNodeState, lnum: integer, folded_depth: integer): eve.ux.picker.view.tree.INodeRenderResult

---@alias eve.ux.picker.view.filetree.ITreeviewFileRenderer
---| fun(ctx: eve.ux.picker.view.filetree.ITreeviewRendererContext, node: std.collection.filetree.INode, nodestate: eve.ux.picker.view.filetree.IFileNodeState, lnum: integer): eve.ux.picker.view.tree.INodeRenderResult

---@alias eve.ux.picker.view.filetree.ITreeviewLocationRenderer
---| fun(ctx: eve.ux.picker.view.filetree.ITreeviewRendererContext, node: std.collection.filetree.INode, nodestate: eve.ux.picker.view.filetree.IFileNodeState, locationstate: eve.ux.picker.view.filetree.ILocationNodeState, lnum: integer): eve.ux.picker.view.tree.INodeRenderResult

---@class eve.ux.picker.view.filetree.IDirectoryNodeState : eve.ux.picker.view.tree.IContainerNodeState

---@class eve.ux.picker.view.filetree.IFileNodeState : eve.ux.picker.view.tree.ILeafNodeState
---@field public locations              eve.ux.picker.view.filetree.ILocationNodeState|nil

---@class eve.ux.picker.view.filetree.ILocationNodeState : eve.ux.picker.view.tree.ILeafLocationState
---@field public lnum                   integer
---@field public col                    ?integer

---@class eve.ux.picker.view.filetree.IListviewRendererContext
---@field public rootnode               std.collection.filetree.INode
---@field public rootstate              eve.ux.picker.view.filetree.IDirectoryNodeState
---@field public tree                   std.collection.IReadonlyFiletree
---@field public view                   eve.ux.picker.FiletreeView

---@class eve.ux.picker.view.filetree.ITreeviewRendererContext
---@field public rootnode               std.collection.filetree.INode
---@field public rootstate              eve.ux.picker.view.filetree.IDirectoryNodeState
---@field public tree                   std.collection.IReadonlyFiletree
---@field public view                   eve.ux.picker.FiletreeView

----------------------------------------------------------------------------------------------------

local DEFAULT_NSNR_MATCHES = eve.var.nsnr.view_filetree_matches ---@type integer

---@class eve.ux.picker.view.IFiletreeProps
---@field public name                   string
---@field public tree                   std.collection.IFiletree
---@field public indent                 ?string
---@field public indent_hln             ?string
---
---@field public listview_file_renderer       ?eve.ux.picker.view.filetree.IListviewFileRenderer
---@field public listview_location_renderer   ?eve.ux.picker.view.filetree.IListviewLocationRenderer
---@field public treeview_directory_renderer  ?eve.ux.picker.view.filetree.ITreeviewDirectoryRenderer
---@field public treeview_file_renderer       ?eve.ux.picker.view.filetree.ITreeviewFileRenderer
---@field public treeview_location_renderer   ?eve.ux.picker.view.filetree.ITreeviewLocationRenderer

---@class eve.ux.picker.FiletreeView
---@field protected _filetree           std.collection.IFiletree
---@field protected _view               eve.ux.picker.TreeView
---@field public insert                 fun(self: eve.ux.picker.FiletreeView, uuid: string, state: eve.ux.picker.view.tree.INodeState): eve.ux.picker.FiletreeView
local M = {}
M.__index = M

---@param props                         eve.ux.picker.view.IFiletreeProps
---@return eve.ux.picker.FiletreeView
function M.new(props)
  local name = props.name ---@type string
  local fullname = string.format("%s@%s", __module_name__, name) ---@type string
  local filetree = props.tree ---@type std.collection.IFiletree
  local indent = props.indent ---@type string|nil
  local indent_hln = props.indent_hln ---@type string|nil

  local listview_file_renderer = props.listview_file_renderer or M.default_listview_file_node_renderer ---@type eve.ux.picker.view.filetree.IListviewFileRenderer
  local listview_location_renderer = props.listview_location_renderer or M.default_listview_location_node_renderer ---@type eve.ux.picker.view.filetree.IListviewLocationRenderer
  local treeview_directory_renderer = props.treeview_directory_renderer or M.default_treeview_directory_node_renderer ---@type eve.ux.picker.view.filetree.ITreeviewDirectoryRenderer
  local treeview_file_renderer = props.treeview_file_renderer or M.default_treeview_file_node_renderer ---@type eve.ux.picker.view.filetree.ITreeviewFileRenderer
  local treeview_location_renderer = props.treeview_location_renderer or M.default_treeview_location_node_renderer ---@type eve.ux.picker.view.filetree.ITreeviewLocationRenderer

  local view = eve.ux.picker.TreeView.new({
    name = name,
    fullname = fullname,
    indent = indent,
    indent_hln = indent_hln,
    tree = filetree,
    render_listview_leaf = function(ctx, node, nodestate, lnum)
      ---@cast ctx                      eve.ux.picker.view.filetree.IListviewRendererContext
      ---@cast node                     std.collection.filetree.INode
      ---@cast nodestate                eve.ux.picker.view.filetree.IFileNodeState
      return listview_file_renderer(ctx, node, nodestate, lnum)
    end,
    render_listview_location = function(ctx, node, nodestate, locationstate, lnum)
      ---@cast ctx                      eve.ux.picker.view.filetree.IListviewRendererContext
      ---@cast node                     std.collection.filetree.INode
      ---@cast nodestate                eve.ux.picker.view.filetree.IFileNodeState
      ---@cast locationstate            eve.ux.picker.view.filetree.ILocationNodeState
      return listview_location_renderer(ctx, node, nodestate, locationstate, lnum)
    end,
    render_treeview_container = function(ctx, node, nodestate, lnum, folded_depth)
      ---@cast ctx                      eve.ux.picker.view.filetree.ITreeviewRendererContext
      ---@cast node                     std.collection.filetree.INode
      ---@cast nodestate                eve.ux.picker.view.filetree.IDirectoryNodeState
      return treeview_directory_renderer(ctx, node, nodestate, lnum, folded_depth)
    end,
    render_treeview_leaf = function(ctx, node, nodestate, lnum)
      ---@cast ctx                      eve.ux.picker.view.filetree.ITreeviewRendererContext
      ---@cast node                     std.collection.filetree.INode
      ---@cast nodestate                eve.ux.picker.view.filetree.IFileNodeState
      return treeview_file_renderer(ctx, node, nodestate, lnum)
    end,
    render_treeview_location = function(ctx, node, nodestate, locationstate, lnum)
      ---@cast ctx                      eve.ux.picker.view.filetree.ITreeviewRendererContext
      ---@cast node                     std.collection.filetree.INode
      ---@cast nodestate                eve.ux.picker.view.filetree.IFileNodeState
      ---@cast locationstate            eve.ux.picker.view.filetree.ILocationNodeState
      return treeview_location_renderer(ctx, node, nodestate, locationstate, lnum)
    end,
  })

  local self = setmetatable({}, M)
  self._filetree = filetree
  self._view = view
  return self
end

----------------------------------------------------------------------------------------------------

---@return eve.ux.picker.FiletreeView
function M:clear()
  self:__health__()
  self._view:clear()
  return self
end

---@return nil
function M:dispose()
  self._view:dispose()
end

---@return boolean
function M:isdisposed()
  return self._view:isdisposed()
end

---@param uuid                          string
---@return boolean
function M:isselected(uuid)
  return self._view:isselected(uuid)
end

---@param uuid                          string
---@return boolean
function M:isvisible(uuid)
  return self._view:isvisible(uuid)
end

---@param uuid                          string
---@param value                         eve.ux.picker.view.tree.CollapseActionEnum
---@param recursive                     boolean|nil
---@return eve.ux.picker.FiletreeView
function M:collapse(uuid, value, recursive)
  self._view:collapse(uuid, value, recursive)
  return self
end

---@param uuid                          string
---@return eve.ux.picker.FiletreeView
function M:empty(uuid)
  self._view:empty(uuid)
  return self
end

---@param uuid                          string
---@param nodestate                     eve.ux.picker.view.tree.INodeState
---@return eve.ux.picker.FiletreeView
function M:insert(uuid, nodestate)
  self._view:insert(uuid, nodestate)
  return self
end

---@param nodeuuid                      string
---@return eve.ux.picker.FiletreeView
function M:mark_node_invisible(nodeuuid)
  self._view:mark_node_invisible(nodeuuid)
  return self
end

---@return eve.ux.picker.FiletreeView
function M:mark_cache_match_dirty()
  self._view:mark_cache_match_dirty()
  return self
end

---@return eve.ux.picker.FiletreeView
function M:mark_cache_selected_dirty()
  self._view:mark_cache_selected_dirty()
  return self
end

---@return eve.ux.picker.FiletreeView
function M:mark_cache_listview_dirty()
  self._view:mark_cache_listview_dirty()
  return self
end

---@return eve.ux.picker.FiletreeView
function M:mark_cache_treeview_dirty()
  self._view:mark_cache_treeview_dirty()
  return self
end

---@param params                        eve.ux.picker.view.tree.IMatchParams
---@return string[]
function M:match(params)
  return self._view:match(params)
end

---@param uuid                          string
---@return eve.ux.picker.FiletreeView
function M:remove(uuid)
  self._view:remove(uuid)
  return self
end

---@param uuid                          string
---@return eve.ux.picker.view.filetree.INodeState|nil
function M:retrieve(uuid)
  self:__health__()
  local nodestate = self._view.statemap[uuid] ---@type eve.ux.picker.view.tree.INodeState|nil
  ---@cast nodestate                    eve.ux.picker.view.filetree.INodeState|nil
  return nodestate
end

---@param nodeuuid                      string
---@param selected                      boolean
---@return eve.ux.picker.FiletreeView
function M:set_selected(nodeuuid, selected)
  self._view:set_selected(nodeuuid, selected)
  return self
end

---@param uuid                          string
---@param selected                      boolean
---@param only_visible                  boolean|nil
---@return eve.ux.picker.FiletreeView
function M:toggle_select(uuid, selected, only_visible)
  self._view:toggle_select(uuid, selected, only_visible)
  return self
end

----------------------------------------------------------------------------------------------------

---@param root                          string|nil
---@return string[]
function M:collect_file_uuids(root)
  return self._view:collect_leafs(root)
end

---@param root                          string|nil
---@return table<string, true>
function M:collect_selected(root)
  return self._view:collect_selected(root)
end

---@return eve.ux.picker.FiletreeView
function M:clear_locations()
  self:__health__()

  local filetree = self._filetree ---@type std.collection.IReadonlyFiletree
  local view = self._view ---@type eve.ux.picker.TreeView
  local statemap = view.statemap ---@type table<string, eve.ux.picker.view.tree.INodeState>
  ---@cast statemap                     table<string, eve.ux.picker.view.filetree.INodeState>

  filetree:quick_traverse(filetree.root, function(_, node)
    if node.data.filetype == "file" then
      local nodestate = statemap[node.uuid]
      if nodestate ~= nil then
        nodestate.locations = nil
      end
    end
  end)
  return self
end

---@param fileuuid                     string
---@param lnum                          integer
---@param col                           integer|nil
---@param data                          unknown|nil
---@return eve.ux.picker.FiletreeView
function M:insert_location(fileuuid, lnum, col, data)
  self:__health__()

  local view = self._view ---@type eve.ux.picker.TreeView
  local statemap = view.statemap ---@type table<string, eve.ux.picker.view.tree.INodeState>
  ---@cast statemap                     table<string, eve.ux.picker.view.filetree.INodeState>

  local leafstate = statemap[fileuuid]
  if leafstate == nil or leafstate.nodetype ~= "leaf" then
    std.reporter.error({
      from = view.fullname,
      subject = "insert_location",
      message = string.format("Cannot retrieve leaf state by the given fileuuid(%s)", fileuuid),
      details = { fileuuid = fileuuid, lnum = lnum, col = col, data = data },
    })
    return self
  end

  ---@type eve.ux.picker.view.filetree.ILocationNodeState
  local locationstate = {
    nodetype = "location",
    leafuuid = fileuuid,
    locationuuid = string.format("%s:%d:%d", fileuuid, lnum, col or 0),
    tick_invisible = 0,
    lnum = lnum,
    col = col,
    data = data,
  }
  statemap[locationstate.locationuuid] = locationstate

  if leafstate.locations == nil then
    leafstate.locations = { locationstate } ---@type eve.ux.picker.view.filetree.ILocationNodeState[]
    return self
  end

  local N = #leafstate.locations ---@type integer
  local index = N + 1 ---@type integer
  for i = 1, N, 1 do
    local location = leafstate.locations[i] ---@type eve.ux.picker.view.filetree.ILocationNodeState
    if location.locationuuid == locationstate.locationuuid then
      index = i ---@type integer
      break
    end
  end

  leafstate.locations[index] = locationstate
  return self
end

---@param params                        eve.ux.picker.view.tree.IRenderListviewParams
---@return eve.ux.picker.view.tree.IRenderResult
function M:render_listview(params)
  self:__health__()

  local nsnr = DEFAULT_NSNR_MATCHES ---@type integer
  local bufnr = params.bufnr ---@type integer
  local only_matched = params.only_matched ---@type boolean

  local result = self._view:render_listview(params)
  local uuids = result.lnum2uuid ---@type string[]
  local N = #uuids ---@type integer

  vim.api.nvim_buf_clear_namespace(bufnr, nsnr, 0, -1)

  if N < 1 then
    return result
  end

  local filetree = self._filetree ---@type std.collection.IReadonlyFiletree
  local view = self._view ---@type eve.ux.picker.TreeView
  local statemap = view.statemap ---@type table<string, eve.ux.picker.view.tree.INodeState>
  ---@cast statemap                     table<string, eve.ux.picker.view.filetree.INodeState>

  local tick_matched = view._tick_matched ---@type integer

  local rootuuid = params.rootuuid ~= nil and params.rootuuid or filetree.root ---@type string
  local rootnode = filetree:retrieve(rootuuid) ---@type std.collection.filetree.INode|nil
  if rootnode == nil then
    std.reporter.error({
      from = view.fullname,
      subject = "render_listview",
      message = "Cannot retrieve the root node",
      details = {
        bufnr = bufnr,
        rootuuid = rootuuid,
      },
    })
    return result
  end

  if only_matched then
    local indents = result.indents ---@type string[]
    for lnum = 1, N, 1 do
      local uuid = uuids[lnum] ---@type string
      local nodestate = statemap[uuid] ---@type eve.ux.picker.view.filetree.INodeState|nil
      if nodestate ~= nil and nodestate.tick_matched == tick_matched and nodestate.cache_match ~= nil then
        local node = filetree:retrieve(uuid) ---@type std.collection.filetree.INode|nil
        if node ~= nil then
          local row = lnum - 1 ---@type integer
          local offset_final = #indents[lnum] + #node.data.fileicon + 1 ---@type integer
          local rootpath = rootnode.data.filepath ---@type string
          local displayed_filepath = #rootpath < 2 and node.data.filepath or node.data.filepath:sub(#rootpath + 2) ---@type string
          local L = #displayed_filepath ---@type integer
          local offset_filepath = #node.data.filepath - L ---@type integer

          local matches = nodestate.cache_match.matches ---@type std.t.IMatchPoint[]
          for _, m in ipairs(matches) do
            local l = m.l - offset_filepath
            local r = m.r - offset_filepath
            if r > 0 and l < L then
              l = l < 0 and 0 or l ---@type integer
              r = r < L and r or L ---@type integer
              vim.hl.range(bufnr, nsnr, "f_pk_matches", { row, offset_final + l }, { row, offset_final + r })
            end
          end
        end
      end
    end
  end
  return result
end

---@param params                        eve.ux.picker.view.tree.IRenderTreeviewParams
---@return eve.ux.picker.view.tree.IRenderResult
function M:render_treeview(params)
  self:__health__()
  local nsnr = DEFAULT_NSNR_MATCHES ---@type integer
  local bufnr = params.bufnr ---@type integer
  local only_matched = params.only_matched ---@type boolean

  local result = self._view:render_treeview(params)
  local uuids = result.lnum2uuid ---@type string[]
  local N = #uuids ---@type integer

  vim.api.nvim_buf_clear_namespace(bufnr, nsnr, 0, -1)

  if N < 1 then
    return result
  end

  local indents = result.indents ---@type string[]
  local filetree = self._filetree ---@type std.collection.IReadonlyFiletree
  local view = self._view ---@type eve.ux.picker.TreeView
  local tick_matched = view._tick_matched ---@type integer
  local statemap = view.statemap ---@type table<string, eve.ux.picker.view.tree.INodeState>
  ---@cast statemap                     table<string, eve.ux.picker.view.filetree.INodeState>

  if only_matched then
    for lnum = 1, N, 1 do
      local uuid = uuids[lnum] ---@type string
      local nodestate = statemap[uuid] ---@type eve.ux.picker.view.filetree.INodeState|nil
      if
        nodestate ~= nil
        and nodestate.nodetype == "leaf"
        and nodestate.tick_matched == tick_matched
        and nodestate.cache_match ~= nil
      then
        local node = filetree:retrieve(uuid) ---@type std.collection.filetree.INode|nil
        if node ~= nil then
          local row = lnum - 1 ---@type integer
          local offset_final = #indents[lnum] + #node.data.fileicon + 1 ---@type integer
          local basename = node.data.basename ---@type string
          local L = #basename ---@type integer
          local offset_basename = #node.data.filepath - L ---@type integer

          local matches = nodestate.cache_match.matches ---@type std.t.IMatchPoint[]
          for _, m in ipairs(matches) do
            local l = m.l - offset_basename ---@type integer
            local r = m.r - offset_basename ---@type integer
            if r > 0 and l < L then
              l = l < 0 and 0 or l ---@type integer
              r = r < L and r or L ---@type integer
              vim.hl.range(bufnr, nsnr, "f_pk_matches", { row, offset_final + l }, { row, offset_final + r })
            end
          end
        end
      end
    end
  end

  return result
end

---@param cwd                           string
---@param filepaths                     string[]
---@param with_locations                boolean
---@return eve.ux.picker.FiletreeView
function M:reset_filepaths(cwd, filepaths, with_locations)
  self:__health__()

  local selected_set = self:collect_selected() ---@type table<string, true>
  self:clear()

  local filetree = self._filetree ---@type std.collection.IFiletree
  local view = self._view ---@type eve.ux.picker.TreeView
  local tick_selected = view._tick_selected ---@type integer
  local statemap = view.statemap ---@type table<string, eve.ux.picker.view.tree.INodeState>
  ---@cast statemap                     table<string, eve.ux.picker.view.filetree.INodeState>

  filetree:reset(cwd, filepaths, with_locations)
  filetree:unsafe_traverse(filetree.root, function(ctx)
    local nodemap = ctx.nodemap ---@type table<string, std.collection.filetree.INode>
    local rootnode = ctx.rootnode ---@type std.collection.filetree.INode

    ---@param node                      std.collection.filetree.INode
    ---@return nil
    local function traverse(node)
      if node.data.filetype == "directory" then
        ---@type eve.ux.picker.view.filetree.IDirectoryNodeState
        local nodestate = {
          nodetype = "container",
          collapsed = false,
          tick_invisible = 0,
          tick_matched = 0,
          tick_selected = selected_set[node.uuid] and tick_selected or 0,
          tick_selected_maximum = 0,
        }
        statemap[node.uuid] = nodestate

        for _, uuid in ipairs(node.children) do
          local childnode = nodemap[uuid] ---@type std.collection.filetree.INode|nil
          if childnode ~= nil then
            traverse(childnode)
          end
        end
        return
      end

      if node.data.filetype == "file" then
        ---@type eve.ux.picker.view.filetree.IFileNodeState
        local nodestate = {
          nodetype = "leaf",
          collapsed = false,
          tick_invisible = 0,
          tick_matched = 0,
          tick_selected = selected_set[node.uuid] and tick_selected or 0,
          text = node.data.filepath,
          text_lower = node.data.filepath_lower,
        }
        statemap[node.uuid] = nodestate
        return
      end

      std.reporter.error({
        from = view.fullname,
        subject = "reset_filepaths",
        message = "Unexpected filetype",
        details = {
          nodeuuid = node.uuid,
          nodedata = node.data,
        },
      })
    end

    traverse(rootnode)

    if with_locations then
      for _, p in ipairs(filepaths) do
        local filepath, lnum, col = std.string.parse_filepath_with_location(p) ---@type string, integer|nil, integer|nil
        if lnum ~= nil then
          if not std.path.is_absolute(filepath) then
            filepath = cwd .. std.env.PATH_SEP .. filepath ---@type string
          end

          local fileuuid = std.Filetree.uuid(filepath) ---@type string
          local filenode = nodemap[fileuuid] ---@type std.collection.filetree.INode|nil
          local nodestate = statemap[fileuuid]

          if filenode ~= nil and nodestate ~= nil then
            local locationuuid = string.format("%s:%d:%d", fileuuid, lnum, col or 0) ---@type string

            ---@type eve.ux.picker.view.filetree.ILocationNodeState
            local location = {
              nodetype = "location",
              leafuuid = fileuuid,
              locationuuid = locationuuid,
              tick_invisible = 0,
              lnum = lnum,
              col = col,
            }
            statemap[locationuuid] = location

            local locations = nodestate.locations or {} ---@type eve.ux.picker.view.filetree.ILocationNodeState[]
            locations[#locations + 1] = location ---@type eve.ux.picker.view.filetree.ILocationNodeState
            nodestate.locations = locations ---@type eve.ux.picker.view.filetree.ILocationNodeState[]
          end
        end
      end
    end
  end)

  return self
end

----------------------------------------------------------------------------------------------------

---@type eve.ux.picker.view.filetree.IListviewFileRenderer
function M.default_listview_file_node_renderer(ctx, node)
  local rootnode = ctx.rootnode ---@type std.collection.filetree.INode
  local fileicon = node.data.fileicon ---@type string
  local fileicon_hln = node.data.fileicon_hln ---@type string
  local filepath = #rootnode.data.filepath < 2 and node.data.filepath
    or node.data.filepath:sub(#rootnode.data.filepath + 2)
  local text = string.format("%s %s", fileicon, filepath) ---@type string
  local highlights = { { coll = 0, colr = #fileicon + 1, hlname = fileicon_hln } } ---@type std.t.IHighlightInline[]
  return { text = text, highlights = highlights }
end

---@type eve.ux.picker.view.filetree.IListviewLocationRenderer
function M.default_listview_location_node_renderer(_, _, _, locationstate)
  local lnum = locationstate.lnum
  local col = locationstate.col
  local text = col ~= nil and string.format("%4d:%-4d", lnum, col) or string.format("%4d:", lnum) ---@type string
  local highlights = { { coll = 0, colr = #text, hlname = "f_ft_position" } } ---@type std.t.IHighlightInline[]
  return { text = text, highlights = highlights }
end

---@type eve.ux.picker.view.filetree.ITreeviewDirectoryRenderer
function M.default_treeview_directory_node_renderer(ctx, node, nodestate, _, folded_depth)
  local basename = node.data.basename ---@type string
  local fileicon = node.data.fileicon ---@type string
  local fileicon_hln = node.data.fileicon_hln ---@type string
  if not nodestate.collapsed then
    fileicon = eve.icon.filetype.FolderOpen
  end

  if folded_depth < 1 then
    local text = string.format("%s %s", fileicon, basename) ---@type string

    ---@type std.t.IHighlightInline[]
    local highlights = {
      { coll = 0, colr = #fileicon + 1, hlname = fileicon_hln },
      { coll = #fileicon + 1, colr = #text, hlname = "f_ft_dirname" },
    }
    return { text = text, highlights = highlights }
  end

  local tree = ctx.tree ---@type std.collection.IReadonlyFiletree

  local basenames = {} ---@type string[]
  basenames[folded_depth + 1] = basename ---@type string

  local o = node ---@type std.collection.filetree.INode
  for index = folded_depth, 1, -1 do
    local uuid_parent = o.parent ---@type string
    o = tree:retrieve(uuid_parent) or o ---@type std.collection.filetree.INode
    basenames[index] = o.data.basename ---@type string
  end

  local start_index = 1 ---@type integer
  local text ---@type string
  if basenames[1] == "/" then
    text = string.format("%s %s", fileicon, "/" .. basenames[2]) ---@type string
    start_index = 2
  else
    text = string.format("%s %s", fileicon, basenames[1]) ---@type string
  end

  ---@type std.t.IHighlightInline[]
  local highlights = {
    { coll = 0, colr = #fileicon + 1, hlname = fileicon_hln },
    { coll = #fileicon + 1, colr = #text, hlname = "f_ft_dirname" },
  }

  for index = start_index + 1, #basenames, 1 do
    local piece = basenames[index] ---@type string
    local offset = #text ---@type integer
    text = text .. string.format("/%s", piece)
    highlights[#highlights + 1] = { coll = offset, colr = offset + 1, hlname = "f_ft_pathsep" }
    highlights[#highlights + 1] = { coll = offset + 1, colr = #text, hlname = "f_ft_dirname" }
  end

  return { text = text, highlights = highlights }
end

---@type eve.ux.picker.view.filetree.ITreeviewFileRenderer
function M.default_treeview_file_node_renderer(_, node)
  local basename = node.data.basename ---@type string
  local fileicon = node.data.fileicon ---@type string
  local fileicon_hln = node.data.fileicon_hln ---@type string
  local text = string.format("%s %s", fileicon, basename) ---@type string

  ---@type std.t.IHighlightInline[]
  local highlights = {
    { coll = 0, colr = #fileicon + 1, hlname = fileicon_hln },
    { coll = #fileicon + 1, colr = #text, hlname = "f_ft_filename" },
  }
  return { text = text, highlights = highlights }
end

---@type eve.ux.picker.view.filetree.ITreeviewLocationRenderer
function M.default_treeview_location_node_renderer(_, _, _, locationstate)
  local lnum = locationstate.lnum
  local col = locationstate.col
  local text = col ~= nil and string.format("%4d:%-4d", lnum, col) or string.format("%4d:", lnum) ---@type string
  local highlights = { { coll = 0, colr = #text, hlname = "f_ft_position" } } ---@type std.t.IHighlightInline[]
  return { text = text, highlights = highlights }
end

----------------------------------------------------------------------------------------------------

---@protected
---@return nil
function M:__health__()
  local view = self._view ---@type eve.ux.picker.TreeView
  if view:isdisposed() then
    local message = string.format("[%s] has been disposed.", view.fullname) ---@type string
    error(message)
  end
end

return M
